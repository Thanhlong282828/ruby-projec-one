require "test_helper"
require "tmpdir"
load Rails.root.join("bin/audit-env-features")

class EnvFeatureAuditTest < ActiveSupport::TestCase
  def with_projects
    Dir.mktmpdir("env-audit-") do |directory|
      ruby_root = Pathname.new(directory).join("ruby")
      laravel_root = Pathname.new(directory).join("laravel")
      [ ruby_root, laravel_root ].each { |root| FileUtils.mkdir_p(root.join("config")) }
      audit = EnvFeatureAudit.new(
        ruby_root: ruby_root, laravel_root: laravel_root,
        catalog_path: Rails.root.join("docs/env-feature-map.json")
      )
      yield audit, ruby_root, laravel_root
    end
  end

  test "audit never exports or evaluates values and records duplicate key locations" do
    with_projects do |audit, ruby_root, laravel_root|
      marker = ruby_root.join("must_not_exist")
      laravel_root.join(".env").write("DB_PASSWORD=NEVER_EXPORT_LARAVEL_SECRET\nDB_PASSWORD=SECOND_SECRET\nAPP_NAME=$(touch #{marker})\n")
      ruby_root.join(".env").write("DATABASE_PASSWORD=NEVER_EXPORT_RUBY_SECRET\n")
      report = audit.report
      encoded = JSON.generate(report)
      %w[NEVER_EXPORT_LARAVEL_SECRET SECOND_SECRET NEVER_EXPORT_RUBY_SECRET $(touch].each do |value|
        assert_not_includes encoded, value
      end
      assert_not marker.exist?
      duplicate = report[:duplicates][:laravel].first
      assert_equal "DB_PASSWORD", duplicate[:key]
      assert_equal [ 1, 2 ], duplicate[:lines]
      audit.write(report)
      tutorial = ruby_root.join("DOI_CHIEU_ENV_LARAVEL_DJI_RUBY.txt").read
      assert_includes tutorial, "BANG 1"
      assert_includes tutorial, "BANG 2"
      assert_includes tutorial, "BANG 3"
      assert_not_includes tutorial, "NEVER_EXPORT_"
      assert_equal report[:totals][:laravel_declared_keys], JSON.parse(ruby_root.join("docs/env-feature-audit.json").read).fetch("totals").fetch("laravel_declared_keys")
    end
  end

  test "static source references exclude Ruby comments and find undocumented keys" do
    with_projects do |audit, ruby_root, laravel_root|
      ruby_root.join("config/runtime.rb").write(<<~'SOURCE')
        # ENV.fetch("COMMENT_ONLY")
        config = ENV.fetch("DATABASE_PASSWORD") # ENV.fetch("INLINE_COMMENT")
        url = "https://#{ENV.fetch('APP_HOST')}"
      SOURCE
      laravel_root.join("config/service.php").write("<?php return ['key' => env(\n 'GCS_BUCKET'\n)];")
      FileUtils.mkdir_p(laravel_root.join("vendor"))
      laravel_root.join("vendor/ignored.php").write("<?php env('VENDOR_ONLY');")
      report = audit.report
      assert_equal(%w[APP_HOST DATABASE_PASSWORD], report[:ruby_keys].pluck(:key))
      assert_equal([ "GCS_BUCKET" ], report[:laravel_keys].pluck(:key))
      assert_empty report[:laravel_keys].first[:declarations]
      assert_equal "missing", report[:laravel_keys].first[:status]
      assert_equal "config/runtime.rb", report[:ruby_keys].first[:references].first[:file]
    end
  end

  test "unknown environment key is left for review rather than marked implemented" do
    with_projects do |audit, _, laravel_root|
      laravel_root.join(".env.example").write("NEW_UNKNOWN_PROVIDER_TOKEN=DO_NOT_EXPORT_ME\n")
      row = audit.report[:laravel_keys].first
      assert_equal "needs_review", row[:status]
      assert_empty row[:ruby_keys]
    end
  end
  test "quoted multiline secret fragments are never mistaken for key declarations" do
    with_projects do |audit, ruby_root, laravel_root|
      laravel_root.join(".env").write(<<~'ENVFILE')
        PASSPORT_PRIVATE_KEY="first line
        NEVER_EXPORT_PRIVATE_KEY_FRAGMENT=base64padding
        another line with \" escaped quote
        final line"
        APP_ENV=local
      ENVFILE
      ruby_root.join(".env").write("DATABASE_PASSWORD='first line\nNEVER_EXPORT_PASSWORD_FRAGMENT=value\nlast line'\nAPP_HOST=example.test\n")
      report = audit.report
      assert_equal(%w[APP_ENV PASSPORT_PRIVATE_KEY], report[:laravel_keys].pluck(:key))
      assert_equal(%w[APP_HOST DATABASE_PASSWORD], report[:ruby_keys].pluck(:key))
      assert_not_includes JSON.generate(report), "NEVER_EXPORT_"
    end
  end
end
