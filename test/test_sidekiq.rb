# frozen_string_literal: true

require_relative "helper"

describe Sidekiq do
  before do
    @config = Sidekiq
  end

  describe "json processing" do
    it "handles json" do
      assert_equal({"foo" => "bar"}, Sidekiq.load_json("{\"foo\":\"bar\"}"))
      assert_equal "{\"foo\":\"bar\"}", Sidekiq.dump_json({"foo" => "bar"})
    end
  end

  describe "redis connection" do
    it "returns error without creating a connection if block is not given" do
      assert_raises(ArgumentError) do
        @config.redis
      end
    end
  end

  describe "❨╯°□°❩╯︵┻━┻" do
    before { $stdout = StringIO.new }
    after { $stdout = STDOUT }

    it "allows angry developers to express their emotional constitution and remedies it" do
      Sidekiq.❨╯°□°❩╯︵┻━┻
      assert_equal "Calm down, yo.\n", $stdout.string
    end
  end

  describe "options" do
    it "provides attribute writers" do
      assert_equal 3, @config.concurrency = 3
      assert_equal %w[foo bar], @config.queues = ["foo", "bar"]
    end
  end

  describe "lifecycle events" do
    it "handles invalid input" do
      config = @config
      config[:lifecycle_events][:startup].clear

      e = assert_raises ArgumentError do
        config.on(:startp)
      end
      assert_match(/Invalid event name/, e.message)
      e = assert_raises ArgumentError do
        config.on("startup")
      end
      assert_match(/Symbols only/, e.message)
      config.on(:startup) do
        1 + 1
      end

      assert_equal 2, config[:lifecycle_events][:startup].first.call
    end
  end

  describe "default_job_options" do
    it "stringifies keys" do
      @old_options = @config.default_job_options
      begin
        @config.default_job_options = {queue: "cat"}
        assert_equal "cat", @config.default_job_options["queue"]
      ensure
        @config.default_job_options = @old_options
      end
    end
  end

  describe "error handling" do
    it "deals with user-specified error handlers which raise errors" do
      output = capture_logging do
        @config.error_handlers << proc { |x, hash|
          raise "boom"
        }
        @config.handle_exception(RuntimeError.new("hello"))
      ensure
        @config.error_handlers.pop
      end
      assert_includes output, "boom"
      assert_includes output, "ERROR"
    end
  end

  describe "redis connection" do
    it "does not continually retry" do
      assert_raises Redis::CommandError do
        @config.redis do |c|
          raise Redis::CommandError, "READONLY You can't write against a replica."
        end
      end
    end

    it "reconnects if connection is flagged as readonly" do
      counts = []
      @config.redis do |c|
        counts << c.info["total_connections_received"].to_i
        raise Sidekiq::RedisConnection.adapter::CommandError, "READONLY You can't write against a replica." if counts.size == 1
      end
      assert_equal 2, counts.size
      assert_equal counts[0] + 1, counts[1]
    end

    it "reconnects if instance state changed" do
      counts = []
      @config.redis do |c|
        counts << c.info["total_connections_received"].to_i
        raise Sidekiq::RedisConnection.adapter::CommandError, "UNBLOCKED force unblock from blocking operation, instance state changed (master -> replica?)" if counts.size == 1
      end
      assert_equal 2, counts.size
      assert_equal counts[0] + 1, counts[1]
    end
  end

  describe "redis info" do
    it "calls the INFO command which returns at least redis_version" do
      output = @config.redis_info
      assert_includes output.keys, "redis_version"
    end
  end
end
