require "open3"
require "logger"

class Runner
  attr_reader :cmd, :exit_status, :stdout, :stderr, :pid, :log

  # Run a command, return runner instance
  # @param cmd [String,Array<String>] command to execute
  def self.run(*cmd)
    Runner.new(*cmd).run
  end

  # Run a command, raise Runner::Error if it fails
  # @param cmd [String,Array<String>] command to execute
  # @raise [Runner::Error]
  def self.run!(*cmd)
    Runner.new(*cmd).run!
  end

  # Run a command, return true if it succeeds, false if not
  # @param cmd [String,Array<String>] command to execute
  # @return [Boolean]
  def self.run?(*cmd)
    Runner.new(*cmd).run?
  end

  Error = Class.new(StandardError)

  # @param cmd [String,Array<String>] command to execute
  def initialize(cmd, log = nil)
    @cmd = cmd.is_a?(Array) ? cmd.join(" ") : cmd
    @stdout = +""
    @stderr = +""
    @exit_status = nil
    @log = log
  end

  # @return [Boolean] success or failure?
  def success?
    exit_status.zero?
  end

  # Run the command, return self
  # @return [Runner]
  def run
    Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      until [stdout, stderr].all?(&:eof?)
        readable = IO.select([stdout, stderr])
        next unless readable&.first

        readable.first.each do |stream|
          data = +""
          # rubocop:disable Lint/HandleExceptions
          begin
            stream.read_nonblock(1024, data)
          rescue EOFError
            # ignore, it's expected for read_nonblock to raise EOFError
            # when all is read
          end

          if stream == stdout
            @stdout << data
            if log.nil?
              $stdout.write(data)
            else
              log.info(data)
            end
          else
            @stderr << data
            if log.nil?
              $stderr.write(data)
            else
              log.error(data)
            end
          end
        end
      end
      @exit_status = wait_thr.value.exitstatus
      @pid = wait_thr.pid
    end

    self
  end

  # Run the command no output, return self
  # @return [Runner]
  def run_clean
    Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      until [stdout, stderr].all?(&:eof?)
        readable = IO.select([stdout, stderr])
        next unless readable&.first

        readable.first.each do |stream|
          data = +""
          # rubocop:disable Lint/HandleExceptions
          begin
            stream.read_nonblock(1024, data)
          rescue EOFError
            # ignore, it's expected for read_nonblock to raise EOFError
            # when all is read
          end

          if stream == stdout
            unless log.nil?
              log.info(data)
            end
          else
            unless log.nil?
              log.error(data)
            end
          end
        end
      end
      @exit_status = wait_thr.value.exitstatus
      @pid = wait_thr.pid
    end

    self
  end

  # Run the command and return stdout, raise if fails
  # @return stdout [String]
  # @raise [Runner::Error]
  def run!
    return run.stdout if run.success?

    raise(Error, "command failed, exit: %d - stdout: %s / stderr: %s" % [exit_status, stdout, stderr])
  end

  # Run the command and return true if success, false if failure
  # @return success [Boolean]
  def run?
    run.success?
  end
end
