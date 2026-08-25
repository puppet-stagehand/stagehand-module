# @summary Atomically persist separate desired and observed lock snapshots.
class stagehand::platform_lock::manifest (
  Hash      $desired,
  Hash      $observed,
) {
  $manifest_dir = '/var/lib/stagehand/platform-lock'
  $helper_path = '/usr/local/sbin/stagehand-platform-manifest-write'
  # lint:ignore:strict_indent
  $helper = @("RUBY"/L)
    #!/opt/puppetlabs/puppet/bin/ruby
    require 'json'
    require 'tempfile'

    candidate, destination, expected_kind = ARGV
    root = '/var/lib/stagehand/platform-lock'
    abort('invalid manifest arguments') unless candidate && destination && %w[desired observed].include?(expected_kind)
    abort('manifest root is not a real directory') unless File.directory?(root) && File.realpath(root) == root
    abort('manifest path escapes managed root') unless File.dirname(candidate) == root && File.dirname(destination) == root
    abort('unexpected manifest filename') unless File.basename(candidate) == "#{expected_kind}.json.candidate" && File.basename(destination) == "#{expected_kind}.json"
    abort('manifest candidate is a symlink') if File.symlink?(candidate)
    abort('manifest destination is a symlink') if File.symlink?(destination)

    bytes = File.binread(candidate, 1_048_577)
    abort('manifest candidate is too large') if bytes.bytesize > 1_048_576
    document = JSON.parse(bytes)
    abort('manifest kind mismatch') unless document['schema_version'] == 1 && document['kind'] == expected_kind && document.key?(expected_kind)
    forbidden_key = lambda do |value|
      case value
      when Hash
        value.any? { |key, nested| key.to_s.match?(/(?:password|secret|token|credential|private_key)/i) || forbidden_key.call(nested) }
      when Array
        value.any? { |nested| forbidden_key.call(nested) }
      else
        false
      end
    end
    abort('manifest contains credential-shaped data') if forbidden_key.call(document)

    file = Tempfile.new([".#{expected_kind}.", '.tmp'], root)
    begin
      file.chmod(0600)
      file.binmode
      file.write(bytes)
      file.flush
      file.fsync
      file.close
      File.rename(file.path, destination)
      File.open(root, File::RDONLY) { |directory| directory.fsync }
    ensure
      file.close! if file
    end
    RUBY
  # lint:endignore

  file { $manifest_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }
  file { $helper_path:
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0700',
    content   => $helper,
    show_diff => false,
  }

  ['desired', 'observed'].each |String $kind| {
    $candidate = "${manifest_dir}/${kind}.json.candidate"
    $destination = "${manifest_dir}/${kind}.json"
    $payload = $kind ? {
      'desired' => $desired,
      default   => $observed,
    }
    # inline_template is a Puppet core function. The fixed ERB program only
    # serializes the scoped data value with Ruby's JSON library; untrusted
    # payload bytes are data, never template source. This keeps the manifest
    # writer independent from fixture/module load order.
    $payload_json = inline_template('<%= require "json"; JSON.generate(@payload) %>')
    file { $candidate:
      ensure    => file,
      owner     => 'root',
      group     => 'root',
      mode      => '0600',
      content   => "${payload_json}\n",
      require   => File[$manifest_dir],
      show_diff => false,
    }
    exec { "stagehand-platform-lock-write-${kind}":
      command     => "${helper_path} ${candidate} ${destination} ${kind}",
      refreshonly => true,
      subscribe   => [File[$candidate], File[$helper_path]],
      require     => [File[$manifest_dir], File[$candidate], File[$helper_path]],
      path        => ['/opt/puppetlabs/puppet/bin', '/usr/bin', '/bin'],
      logoutput   => false,
    }
  }
}
