require "openssl"
require "securerandom"
require "fileutils"
# Provisioning only: network disabled; CA private key remains in MySQL volume.
root = "/tls"
certificate = OpenSSL::X509::Certificate.new(File.binread("#{root}/server-cert.pem"))
sans = certificate.extensions.find { |e| e.oid == "subjectAltName" }&.value.to_s
if sans.include?("DNS:mysql") && sans.include?("DNS:localhost") && certificate.not_after > Time.now.utc + (30 * 86_400)
  puts "Local MySQL TLS SAN certificate already valid"
  exit
end
ca = OpenSSL::X509::Certificate.new(File.binread("#{root}/ca.pem"))
ca_key = OpenSSL::PKey.read(File.binread("#{root}/ca-key.pem"))
key = OpenSSL::PKey::RSA.new(2048)
cert = OpenSSL::X509::Certificate.new
cert.version = 2
cert.serial = SecureRandom.random_number((2**128) - 1) + 1
cert.subject = OpenSSL::X509::Name.parse("/CN=mysql")
cert.issuer = ca.subject
cert.public_key = key.public_key
cert.not_before = Time.now.utc - 300
cert.not_after = [ Time.now.utc + (366 * 86_400), ca.not_after ].min
factory = OpenSSL::X509::ExtensionFactory.new
factory.subject_certificate = cert
factory.issuer_certificate = ca
cert.add_extension(factory.create_extension("basicConstraints", "CA:FALSE", true))
cert.add_extension(factory.create_extension("keyUsage", "digitalSignature,keyEncipherment", true))
cert.add_extension(factory.create_extension("extendedKeyUsage", "serverAuth"))
cert.add_extension(factory.create_extension("subjectAltName", "DNS:mysql,DNS:localhost,IP:127.0.0.1"))
cert.sign(ca_key, OpenSSL::Digest.new('SHA256'))
{ "server-key.pem" => key.to_pem, "server-cert.pem" => cert.to_pem }.each do |name, pem|
  path = "#{root}/#{name}"
  stat = File.stat(path)
  backup = "#{path}.before-hrm-san"
  unless File.exist?(backup)
    FileUtils.cp(path, backup)
    File.chmod(0600, backup)
    File.chown(stat.uid, stat.gid, backup)
  end
  temp = "#{path}.next"
  File.write(temp, pem, mode: "w", perm: 0600)
  File.chown(stat.uid, stat.gid, temp)
  File.rename(temp, path)
end
puts "Local server certificate prepared; original CA retained; keys kept in data volume"
