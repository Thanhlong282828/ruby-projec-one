require "test_helper"
require "tempfile"
require "openssl"
class MysqlSchemaSecurityTest < ActiveSupport::TestCase
  test "database session uses TLS with a trusted CA and verification enabled" do
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    assert_equal "verify_identity", config[:ssl_mode].to_s
    assert config[:sslverify], "Prepare local CA using bin/prepare-mysql-tls or configure DATABASE_SSL_CA"
    assert File.file?(config.fetch(:sslca))
    cipher = ActiveRecord::Base.connection.select_rows("SHOW SESSION STATUS LIKE 'Ssl_cipher'").first.last
    assert cipher.present?, "MySQL connection must be encrypted"
  end

  test "an untrusted CA is rejected rather than silently disabling certificate verification" do
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=untrusted-test-only")
    cert.public_key = key.public_key
    cert.not_before = Time.now.utc - 60
    cert.not_after = Time.now.utc + 600
    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    options = config.slice(:host, :port, :username, :password, :database, :encoding)
    Tempfile.create([ "untrusted-mysql-ca", ".pem" ]) do |file|
      file.write(cert.to_pem)
      file.flush
      assert_raises(Mysql2::Error) do
        client = Mysql2::Client.new(**options.merge(sslca: file.path, sslverify: true, ssl_mode: :verify_identity))
        client.close
      end
    end
  end

  test "SQL schema preserves trigger DDL without local definer or data counters" do
    assert_equal :sql, Rails.application.config.active_record.schema_format
    schema = Rails.root.join("db/structure.sql").read
    %w[users_membership_insert_guard users_membership_update_guard principal_owns_credentials].each { |name| assert_includes schema, name }
    assert_no_match(/DEFINER=`/, schema)
    assert_no_match(/ AUTO_INCREMENT=\d+/, schema)
  end
end
