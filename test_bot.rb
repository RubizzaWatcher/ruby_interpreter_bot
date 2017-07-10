require 'telegram/bot'
require 'rubygems'
require 'shikashi'
require 'net/http'

include Shikashi
module Shikashi
  # Class for allowing methods in sandbox
  class Privileges
    def allow_methods(*method_names)
      method_names.each do |mn|
        @allowed_methods << mn
      end

      self
    end
  end
end

# Class containg all bot functionality
class TestBot
  def initialize(token)
    @token = token
    @bot = nil
    @last_message = nil
    @allowed_const_read = []
    @allowed_methods = []
    # method whitelist
    methods = Integer.methods + Integer.instance_methods + Array.methods + Array.instance_methods + String.methods + String.instance_methods + Net::HTTP.methods + Net::HTTP.instance_methods + Math.methods+Math.instance_methods
    methods.each do |method|
      @allowed_methods << method
    end
    %i[times puts print each p].each do |method|
      @allowed_methods << method
    end

    [Math].each do |const|
      @allowed_const_read << const
    end
  end

  def with_captured_stdout
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('', 'w')
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  end

  def send_reply(text)
    @bot.api.send_message(chat_id: @last_message.chat.id, text: text)
  end

  def start_bot
    Telegram::Bot::Client.run(@token) do |bot|
      @bot = bot
      bot.listen do |message|
        @last_message = message
        puts message
        case message.text
        when %r{\A\/start}
          bot.api.send_message(chat_id: message.chat.id, text: "Привет, #{message.from.first_name}. Начинаю работать! Напиши /help для подробной информации.")
        when %r{\A\/stop}
          bot.api.send_message(chat_id: message.chat.id, text: "Пока, #{message.from.first_name}. Возвращайся снова!")
        when %r{\A\/help}
          bot.api.send_message(chat_id: message.chat.id, text:
              "/run\nФормат кода: /run {code}\nДоступные методы: times, puts, print, each, p \nПример: \n/run 3.times{|x| puts x*x}")
        when %r{\A\/run}
          else
            message.text.slice! '/run'
          end
          begin
            stdout = with_captured_stdout do
              s = Sandbox.new
              priv = Privileges.new
              priv.allow_const_read(*@allowed_const_read)
              priv.allow_methods(*@allowed_methods)
              s.run(priv, message.text, timeout: 3)
            end
            puts(stdout)
            send_reply("Result:\n#{stdout}")
          rescue => ex
            send_reply("Error:\n#{ex}")
          end
        end
      end
    end
  end

token = File.read('token.txt').chomp!
test_bot = TestBot.new token

test_bot.start_bot
