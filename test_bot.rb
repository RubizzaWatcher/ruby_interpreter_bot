require 'telegram/bot'
require "rubygems"
require "shikashi"
require 'net/http'

include Shikashi
module Shikashi
  class Privileges
    def allow_methods(*method_names)
      method_names.each do |mn|
        @allowed_methods << mn
      end

      self
    end
  end
end

class TestBot


  def initialize(token)

    @token = token
    @bot = NIL
    @last_message=NIL
    @allowed_const_read=Array.new
    @allowed_methods=Array.new
    # method whitelist
    methods=Fixnum.methods+Fixnum.instance_methods+Array.methods+Array.instance_methods+String.methods+String.instance_methods+Net::HTTP.methods+Net::HTTP.instance_methods+Math.methods+Math.instance_methods
    methods.each { |method|
      @allowed_methods << method
    }
    [:times, :puts, :print, :each, :p].each { |method|
      @allowed_methods << method
    }

    [Math].each { |const|
      @allowed_const_read << const
    }

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
      @bot=bot
      bot.listen do |message|
        @last_message = message

        puts message

        case message.text
          when /\A\/start/
            bot.api.send_message(chat_id: message.chat.id, text: "Привет, #{message.from.first_name}. Начинаю работать! Напиши /help для подробной информации.")
          when /\A\/stop/
            bot.api.send_message(chat_id: message.chat.id, text: "Пока, #{message.from.first_name}. Возвращайся снова!")
          when /\A\/help/
            bot.api.send_message(chat_id: message.chat.id, text:
                "/run\nФормат кода: /run {code}\nДоступные методы: times, puts, print, each, p \nПример: \n/run 3.times{|x| puts x*x}\n/run puts 'Я хоть простой бот, но способен на многое.'")
          when /\A\/run/
            if message.text=~ /\A\/run@Energy0124TestBot/
              message.text.slice! '/run@Energy0124TestBot'
            else
              message.text.slice! '/run'
            end
            begin
              stdout=with_captured_stdout {
                s = Sandbox.new
                priv = Privileges.new

                priv.allow_const_read *@allowed_const_read
                priv.allow_methods *@allowed_methods

                s.run(priv, message.text, :timeout => 3)
              }

              puts(stdout)

              send_reply("Result:\n#{stdout}")

            rescue Exception => ex
              send_reply("Error:\n#{ex}")
            end
          #   for fun
          when /fuck/i
            send_reply("Ай-ай-ай, ругаться плохо.")
          when /author/i
            send_reply('Мороз Максим https://github.com/Arvisix')
          when /stupid bot/i
            send_reply('Сам такой! :P')
        end
      end
    end
  end
end


token = File.read("token.txt").chomp!
test_bot=TestBot.new token

test_bot.start_bot
