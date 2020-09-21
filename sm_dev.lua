--[[
访问地址： http://219.147.99.163:81/    (向部分人员公开的全军武器装备采购信息网)
安全模块需求：
(1)当用户访问任意一个页面时，如果未登录，直接跳转到登录页
(2)如果用户已登录，在访问任意一个页面时，会将参数(稿件Id + Token)传递并调用后台鉴权接口判断
   如果返回3-> 未授权，则跳转到401页面
   如果返回2-> 用户未登录，跳转到登录页
   如果返回1-> 允许用户访问
(3)调用后台鉴权接口失败：
返回值状态码非200：      跳转到503页面(内部服务器错误)
请求超时(可能服务器挂了) 跳转到503页面
]]--

--Split Url
--param szFullString:需要切分的字符串
--      szSeparator:以什么形式进行切分
function Split(szFullString, szSeparator)
local nFindStartIndex = 1
local nSplitIndex = 1
local nSplitArray = {}
while true do
   local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)
   if not nFindLastIndex then
    nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))
    break
   end
   nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)
   nFindStartIndex = nFindLastIndex + string.len(szSeparator)
   nSplitIndex = nSplitIndex + 1
end
return nSplitArray
end

local content=""
--(1)获取请求地址中已.shtml结尾的名称
local url= ngx.var.request_uri
local list=Split(url,"/")
for i=1,#list do
local x,y=string.find(list[i],".shtml")
if(x~=nil and y~=nil ) then
 content=string.sub(list[i],0,x-1)
break
end
end
local token=""
--(2)获取请求头中的token(cookie中已unit_token为key  token为value)
local headers_tab = ngx.req.get_headers()
for key, value in pairs(headers_tab) do
  if(key=="cookie") then
     if(value~=nil)then
        local length=#value
        local d,f=string.find(value,"unit_token=")
       if(d~=nil or f~=nil)then
       token=value.sub(value,f+1,length)
        end
	local z,x=string.find(token,";")
        if(z~=nil or x~=nil)then
	token=token.sub(token,0,x-1)
	end
        end
     break
  end
end
-- 涉密系统 dev环境后台鉴权接口的地址
local authUrl="http://127.0.0.1:8081/api/front/jurisdiction/content?"
--(3)根据截取到的地址判断用户是否可以访问
--如果用户已登录
if(token ~=nil and token~="") then
--如果用户已登录，并访问的是具体某个稿件
if(content~=nil and  content~="" and content~="list" and content~="index" and content~="footer_0") then
authUrl=authUrl.."contentId="..content.."&token="..token
else
--如果用户已登录，访问的是首页，列表页，通用页，则请求中只携带Token
authUrl=authUrl.."token="..token
end
else 
--如果用户未登录
if(content~=nil and content~="")then
authUrl=authUrl.."contentId="..content
end
end
--发起后台请求接口查看
local http = require "resty.http"
local httpc = http.new()
local url_background = authUrl
local resStr
local res, err = httpc:request_uri(url_background, {
    method = "GET",
    body = str,
    headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded",
    }
})
--后台服务 接口调用失败 -> 返回{503内部服务器错误！}
if not res then
    ngx.log(ngx.WARN,"failed to request: ", err)
    return ngx.req.set_uri("/503.html", false)
end

ngx.status = res.status
--后台服务 出现非200异常 -> 返回{503内部服务器错误！}
if ngx.status ~= 200 then
    ngx.log(ngx.WARN,"非200状态，ngx.status:"..ngx.status)
    return ngx.req.set_uri("/503.html", false)
end
--截取到后台鉴权接口的返回值 (1 or 2 or 3)
restr = res.body
if(restr=="1")then
if(content=="index" or content=="")then
return ngx.req.set_uri("/index.shtml", false)
else 
local u,i=string.find(url,"?")
if(u~=nil or i~=nil)then
url=url.sub(url,0,u-1)
end
return ngx.req.set_uri(url, false)
end
elseif (restr=="2")then
return ngx.req.set_uri("/login.html", false)
elseif (restr=="3")then
return ngx.req.set_uri("/401.html", false)
end
