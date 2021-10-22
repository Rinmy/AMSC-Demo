require "discordrb"
require "yaml"
require "net/https"
require "json"
require "uri"
require "google/cloud/compute/v1"

def area_option(title: nil, description: "", type: nil)
	color = 0
	author = nil

	case type
	when "failed" then
		color = 16725063
		author = {
			"name" => title,
			"icon_url" => "https://icon-library.com/images/failed-icon/failed-icon-7.jpg"
		}
		title = nil
	when "question" then
		color = 14135295
		author = {
			"name" => title,
			"icon_url" => "https://icooon-mono.com/i/icon_11571/icon_115710_256.png"
		}
		title = nil
	when "clear" then
		color = 3270553
		author = {
			"name" => title,
			"icon_url" => "https://freeiconshop.com/wp-content/uploads/edd/checkmark-flat.png"
		}
		title = nil
	when "load"
		author = {
			"name" => title,
			"icon_url" => "https://i.stack.imgur.com/kOnzy.gif"
		}
		title = nil
	end

	return {
		"title" => title,
		"author" => author,
		"description" => description[0, 2048],
		"color" => color
	}
end

def change_config
	config_file = File.open("./config.yaml", "w")
	YAML.dump(CONFIG, config_file)
	config_file.close
end

def delete_message(message)
	begin
		message.delete()
	rescue
	end
end

class Command
	def start
		begin
			start_message = $event.send_embed("ㅤ", area_option(
				title: "接続中",
				type: "load"
			))

			request = Google::Cloud::Compute::V1::StartInstanceRequest.new(
				instance: "xxxxxx",
				project: "xxxxxx",
				zone: "xxxxxx"
			)
			response = GCP.start(request)

			if response.status.to_s === "RUNNING" then
				start_message.edit("ㅤ", area_option(
					title: "サーバー起動処理中",
					type: "load"
				))
			else
				raise "状態不明"
			end

			request = Google::Cloud::Compute::V1::GetInstanceRequest.new(
				instance: "xxxxxx",
				project: "xxxxxx",
				zone: "xxxxxx"
			)

			for num in 1..5 do
				if num === 5 then
					raise "タイムアウト"
				end

				sleep(6)
				response = GCP.get(request)
				if response.status.to_s === "RUNNING" then
					break
				end
			end

			start_message.edit("ㅤ", area_option(
				title: "サーバー起動完了",
				description: "約1分後にサーバーへログイン可能",
				type: "clear"
			))
		rescue => error
			start_message.edit("ㅤ", area_option(
				title: "接続エラー",
				description: error.to_s,
				type: "failed"
			))
		end

		sleep(10)
		delete_message(start_message)
	end

	def stop
		begin
			stop_message = $event.send_embed("ㅤ", area_option(
				title: "接続中",
				type: "load"
			))

			request = Google::Cloud::Compute::V1::StopInstanceRequest.new(
				instance: "xxxxxx",
				project: "xxxxxx",
				zone: "xxxxxx"
			)
			response = GCP.stop(request)

			if response.status.to_s === "RUNNING" then
				stop_message.edit("ㅤ", area_option(
					title: "サーバー停止処理中",
					type: "load"
				))
			else
				raise "状態不明"
			end

			request = Google::Cloud::Compute::V1::GetInstanceRequest.new(
				instance: "xxxxxx",
				project: "xxxxxx",
				zone: "xxxxxx"
			)

			for num in 1..6 do
				if num === 6 then
					raise "タイムアウト"
				end

				sleep(6)
				response = GCP.get(request)
				puts response.status.to_s
				if response.status.to_s === "TERMINATED" then
					break
				end
			end

			stop_message.edit("ㅤ", area_option(
				title: "サーバー停止完了",
				type: "clear"
			))
		rescue => error
			stop_message.edit("ㅤ", area_option(
				title: "接続エラー",
				description: error.to_s,
				type: "failed"
			))
		end

		sleep(10)
		delete_message(stop_message)
	end

	def status
		begin
			status_message = $event.send_embed("ㅤ", area_option(
				title: "接続中",
				type: "load"
			))

			request = Google::Cloud::Compute::V1::GetInstanceRequest.new(
				instance: "xxxxxx",
				project: "xxxxxx",
				zone: "xxxxxx"
			)
			response = GCP.get(request)

			status = response.status.to_s
			case status
			when "TERMINATED" then
				status = "停止中"
			when "RUNNING" then
				status = "動作中"
			when "STOPPING" then
				status = "停止処理中"
			when "STAGING" then
				status = "起動処理中"
			end

			status_message.edit("ㅤ", area_option(
				title: "サーバーは現在#{status}",
				type: "clear"
			))
		rescue => error
			status_message.edit("ㅤ", area_option(
				title: "接続エラー",
				description: error.to_s,
				type: "failed"
			))
		end

		sleep(10)
		delete_message(status_message)
	end

	def change_prefix
		begin
			change_prefix_message = $event.send_embed("ㅤ", area_option(
				title: "プレフィックスを入力",
				type: "question"
			))

			prefix_name = $event.message.await!.message
			delete_message(prefix_name)

			CONFIG["prefix"] = prefix_name.to_s
			change_config

			change_prefix_message.edit("ㅤ", area_option(
				title: "プレフィックスを「#{prefix_name}」に設定",
				type: "clear"
			))
		rescue
			change_prefix_message.edit("ㅤ", area_option(
				title: "プレフィックスの設定エラー",
				description: error.to_s,
				type: "failed"
			))
		end

		sleep(5)
		delete_message(change_prefix_message)
	end

	def set_server
		begin
			set_message = $event.send_embed("ㅤ", area_option(
				title: "サーバーを入力",
				type: "question"
			))

			instance_name = $event.message.await!.message
			delete_message(instance_name)

			is_server = false
			# すでにconfigにサーバーが登録されている場合
			CONFIG["server"].each do |server|
				if server["id"] === $event.server.id then
					server["instance"] = instance_name.to_s
					is_server = true
					break
				end
			end

			# サーバーが登録されてない時
			unless is_server then
				CONFIG["server"].push({"id" => $event.server.id, "instance" => instance_name.to_s})
			end

			change_config

			set_message.edit("ㅤ", area_option(
				title: "サーバー設定完了",
				type: "clear"
			))
		rescue => error
			set_message.edit("ㅤ", area_option(
				title: "サーバー設定エラー",
				description: error.to_s,
				type: "failed"
			))
		end

		sleep(5)
		delete_message(set_message)
	end
end

CONFIG = YAML.load_file("./config.yaml")

GCP = Google::Cloud::Compute::V1::Instances::Rest::Client.new do |config|
	config.credentials = "./api.json"
end

BOT = Discordrb::Bot.new(
	token: CONFIG["bot"]["token"],
	client_id: CONFIG["bot"]["client"]
)

=begin
url = URI.parse("https://discord.com/api/v8/applications/#{CONFIG["bot"]["application"]}/commands")
https = Net::HTTP.new(url.host, url.port)
https.use_ssl = true
https.open_timeout = 30
https.read_timeout = 30

HEADERS = {
	"Content-Type" => "application/json",
	"Authorization" => "Bot #{CONFIG["bot"]["token"]}"
}

COMMANDS = {
	name: "amsc",
	description: "サーバーの状態を取得",
	options: [
		{
			name: "status",
			description: "サーバーの状態を取得",
			type: 1
		},
		{
			name: "start",
			description: "サーバーを起動する",
			type: 1
		}
	]
}

response = https.post(url.path, COMMANDS.to_json, HEADERS)
puts response.body
=end

BOT.message do |event|
	# コマンド以外無視
	unless /^#{CONFIG["prefix"]} / === event.message.to_s || /^\/amsc / === event.message.to_s then
		next
	end

	delete_message(event.message)

	# プレフィックスを消した上で、コマンドをスペースごとに分割
	command_parts = event.message.to_s.delete_prefix(CONFIG["prefix"]).split(" ");

	# コマンドをアンダーバー形式でcommandに保存 例：/amsc start => amsc_start
	command = ""
	command_parts.each do |parts|
		command += "#{parts}_"
	end
	command.chop!

	$event = event

	# コマンド判別とか処理用のクラス
	command_list = Command.new

	# コマンドの存在チェック
	is_command = Command.method_defined?(command)
	if is_command then
		command_list.public_send(command)
	elsif event.message.to_s === "/amsc change prefix" then
		command_list.public_send("change_prefix")
	end
end

BOT.ready do |event|
	BOT.game = CONFIG["prefix"]
end

BOT.run
