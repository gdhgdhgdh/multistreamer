local Account = require'multistreamer.models.account'
local StreamAccount = require'multistreamer.models.stream_account'

local config = require'multistreamer.config'.get()
local resty_sha1 = require'resty.sha1'
local str = require'resty.string'
local slugify = require('lapis.util').slugify

local M = {}

M.name = 'mixcloud'
M.displayname = 'Mixcloud'
M.allow_sharing = true
M.read_comments = true
M.write_comments = false

function M.create_form()
  return {
    [1] = {
      type = 'text',
      key = 'username',
      required = true,
    },
    [2] = {
      type = 'text',
      key = 'password',
      required = true,
    },
  }
end

function M.metadata_fields()
  return nil,nil
end


function M.metadata_form(account_keystore, stream_keystore)
  return nil,nil
end


function M.save_account(user, account, params)
  -- check that account doesn't already exists
  local account = account
  local err

  local sha1 = resty_sha1:new()
  sha1:update(params.password)
  local url_key = str.to_hex(sha1:final())

  if not account then
    account, err = Account:find({
      network = M.network,
      network_user_id = url_key,
    })
  end

  if not account then
    account, err = Account:create({
      network = M.name,
      network_user_id = url_key,
      name = params.username,
      user_id = user.id,
      slug = slugify(params.username),
    })
    if not account then
        return false,err
    end
  else
    account:update({
      name = params.username,
      slug = slugify(params.username),
    })
  end

  account:set('username',params.username)
  account:set('password',params.password)

  return account, nil, nil
end

function M.metadata_fields()
  return {
    [1] = {
      type = 'text',
      key = 'name',
      required = true,
      value = 'nothing',
    },
  }
end

function M.metadata_form(account_keystore, stream_keystore)
  return nil, nil
end


function M.publish_start(account, stream)
  local some_account_key = account:get('username')
  local param1 = stream:get('username')
  local param2 = stream:get('password')

  -- local res, err = httpc:request_uri('https://www.mixcloud.com/authentication/email-login/', {
  --   method = 'POST',
  --   body = to_json({email = param1, password = param2}),
  -- })

  -- if err or res.status >= 400 then
  --   return false, err or res.body
  -- end
  --       for k,v in pairs(res.headers) do
  --       end
  -- ngx.say(res.body)


  -- Create a new 'UPCOMING' stream and get its ID
  local res, err = httpc:request_uri('https://www.mixcloud.com/graphql', {
    method = 'POST',
    headers = {
      ["content-type"] = "application/json",
      ["referer"] = "https://www.mixcloud.com/",
      ["x-csrftoken"] = "5SFwLJxEtmHJVikefPLI089R2TRpCX6C5qFgbxFkwsrkhFqHOUMnvgGZ1IAVPb67",
      ["cookie"] = "csrftoken=5SFwLJxEtmHJVikefPLI089R2TRpCX6C5qFgbxFkwsrkhFqHOUMnvgGZ1IAVPb67;c=pnhefs3dh1sutf34n4kyvzjrk2mb4rw7",
    },
    body = to_json({variables = { input = { name = "Test stream for multi"}},
                    query = "mutation createLiveStreamMutation( $input: CreateLiveStreamMutationInput!) { createLiveStream(input: $input) { liveStream { id  name } } }"}),
  })

  if err or res.status >= 400 then
    return false, err or res.body
  end

  -- Publish the stream on Mixcloud Live
  local res, err = httpc:request_uri('https://www.mixcloud.com/graphql', {
    method = 'POST',
    headers = {
      ["content-type"] = "application/json",
      ["referer"] = "https://www.mixcloud.com/",
      ["x-csrftoken"] = "5SFwLJxEtmHJVikefPLI089R2TRpCX6C5qFgbxFkwsrkhFqHOUMnvgGZ1IAVPb67",
      ["cookie"] = "csrftoken=5SFwLJxEtmHJVikefPLI089R2TRpCX6C5qFgbxFkwsrkhFqHOUMnvgGZ1IAVPb67;c=pnhefs3dh1sutf34n4kyvzjrk2mb4rw7",
    },
    body = to_json({variables = { input = { id = "TGl2ZVN0cmVhbTo4MDAxMw=="}},
                    query = "mutation startLiveStreamMutation( $input: StartLiveStreamMutationInput!) { startLiveStream(input: $input) { liveStream { streamStatus  id } } }"}),
  })

  if err or res.status >= 400 then
    return false, err or res.body
  end

  -- URL for clicking in the Chat window
  stream:set('http_url',"https://www.mixcloud.com/live/djlocalhost")

  return from_json(res.body).rtmp_url, nil
end

function M.publish_stop(account, stream)
  local some_account_key = account:get('username')
  local param1 = stream:get('username')
  local param2 = stream:get('password')

  local res, err = httpc:request_uri('https://www.mixcloud.com/graphql', {
    method = 'POST',
    headers = {
      ["content-type"] = "application/json",
      ["referer"] = "https://www.mixcloud.com/",
      ["x-csrftoken"] = "5SFwLJxEtmHJVikefPLI089R2TRpCX6C5qFgbxFkwsrkhFqHOUMnvgGZ1IAVPb67",
      ["cookie"] = "csrftoken=5SFwLJxEtmHJVikefPLI089R2TRpCX6C5qFgbxFkwsrkhFqHOUMnvgGZ1IAVPb67;c=pnhefs3dh1sutf34n4kyvzjrk2mb4rw7",
    },
    body = to_json({variables = { input = { id = "TGl2ZVN0cmVhbTo4MDAxMw=="}},
                    query = "mutation endLiveStreamMutation( $input: EndLiveStreamMutationInput!) { endLiveStream(input: $input) { liveStream { id  streamStatus } } }"}),
  })

  if err or res.status >= 400 then
    return false, err or res.body
  end

  stream:unset('http_url')

  return nil
end

function M.check_errors(account)
  return false
end

function M.notify_update(account, stream)
  return true
end

function M.create_comment_funcs(account, stream, send)
  local ws = ws_client:new()
  local ws_ok, ws_err = ws:connect('wss://ws2.mixcloud.com/graphql')

  if not ws_ok then
    ngx_log(ngx.ERR,'[Mixcloud] Unable to connect to websocket: ' .. ws_err)
    return nil, nil, nil, ws_err
  end

  ngx_log(ngx.DEBUG, '[Mixcloud] Connected to websocket: wss://ws2.mixcloud.com/graphql'

  ws:send_text(to_json({type = 'connection_init', payload = {} }))

  local welcome_resp, _, err = ws:recv_frame()
  if not welcome_resp then
    ngx_log(ngx.ERR,'[Mixcloud] Error - did not receive welcome_resp: ' .. err)
    return nil, nil, nil, err
  end
  welcome_resp = from_json(welcome_resp)

  if welcome_resp.type ~= 'connection_ack' then
    ngx_log(ngx.ERR,'[Mixcloud] Error - welcome_resp was not connection_ack')
    return nil,nil,nil,'received unexpected event'
  end

  ngx_log(ngx.DEBUG, '[Mixcloud] Received welcome response')

  body = '{"id":"1","type":"start","payload":{"variables":{"input":{"liveStreamId":"TGl2ZVN0cmVhbTo4MDQ3Mw=="},"uploaderId":"VXNlcjoxMjQ1MTE4OA=="},"extensions":{},"operationName":"","query":"subscription newLiveStreamEventSubscription( $input: NewLiveStreamEventSubscriptionInput! $uploaderId: ID!) { newLiveStreamEvent(input: $input) { __typename  liveStreamEvent { __typename ... on ChatMessage { message user { username isSubscribedToUser(uploaderId: $uploaderId) } } } } } "}}'
  ws:send_text(body)
 
  if send then
    local readRunning = true
    read_func = function()
      while readRunning do
        local data, typ, _ = ws:recv_frame()
        if typ == 'text' then
          local msg = from_json(data)
          if msg.type == 'data' and msg.id == '1' then
            local txt = ""
            local msgtyp
            -- for _,v in ipairs(msg.data.message.message) do
            --   txt = txt .. v.text
            -- end
            if msg.payload.data.newLiveStreamEvent.liveStreamEvent.__typename == 'ChatMessage' then
              msgtyp = 'text'
            else
              msgtyp = 'emote'
            end
            if msgtyp then
              send({
                type = msgtyp,
                from = {
                  name = msg.payload.data.newLiveStreamEvent.liveStreamEvent.user.username,
                  id = name,
                },
                text = msg.payload.data.newLiveStreamEvent.liveStreamEvent.message,
                markdown = escape_markdown(txt),
              })
            end
          end
        end
      end
      return true
    end
    stop_func = function()
      readRunning = false
    end
  end

return read_func, write_func, stop_func
end

function M.create_viewcount_func(account, stream, send)
  return nil,nil
end

return M

