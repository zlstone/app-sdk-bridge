###*
 * 初始化android`s app js sdk
 * @param  {Function} callback [description]
 * @return {[type]}            [description]
###
androidSDKInitialization = ->
  connectWebViewJavascriptBridge = (callback) ->
    if window.WebViewJavascriptBridge
      callback WebViewJavascriptBridge
    else
      document.addEventListener 'WebViewJavascriptBridgeReady', ->
          callback WebViewJavascriptBridge
        , false

  connectWebViewJavascriptBridge (bridge) ->
    bridge.init (message, responseCallback) ->
      console.log 'JS got a message', message
      data = 'Javascript Responds': 'Wee!'
      console.log 'JS responding with', data
      responseCallback data

###*
 * 初始化ios`s app js sdk
 * @param  {Function} callback [description]
 * @return {[type]}            [description]
###
iosSDKInitialization = -> no

###*
 * sdk数据存在列表
 * @type {Object}
###
ua = navigator.userAgent
SDKConfig =
  "360around":
    isMatch: ->
      ua.indexOf('360around') > -1
    getVersion: ->
      data = ua.match( /360around \((.*)\)$/ )
      if data then data[1] else ''
    ios: {}
    android:
      login:
        '*': [ 'goLogin' ]
      qifutong:
        '>=1.3.0.1001': [ 'pay' ]

  web:
    login:
      '*': "http://i.360.cn/login/wap"






###*
 * 客户端系统判定
 * @return {String} 客户端系统名
###
systemConfirm = ->
  if ua.indexOf('iPhone') > -1
    config = require './iosSDKConfig.coffee'
    iosSDKInitialization()
    return 'ios'
  if ua.indexOf('Android') > -1
    config = require './androidSDKConfig.coffee'
    androidSDKInitialization()
    return 'android'
  config = require './webSDKConfig.coffee'
  'other'


###*
 * 版本数据计算
 * @param  {String} _ver 需要换算的版本号
 * @return {Number}      版本换算结果
###
versionConvert = (_ver) ->
  return 0 unless _ver
  _tmp_arr = _ver.split '.'
  ((_tmp_arr[0] - 1 ) * 10 * 10 * 10000 ) + (_tmp_arr[1] * 10 * 10000 ) + (_tmp_arr[2] * 10000 ) + _tmp_arr[3] - 1000


###*
 * 拼接成search数据
 * @param  {Object} json 需要拼接的数据
 * @return {String}      拼接结果
###
searchJoin = (json)->
  return '' unless toString.call( json ) is '[object Object]'
  search = []
  for k,v of json
    search.push "#{k}=#{v}"
  if search.length
    "?#{search.join('&')}"
  else
    ''


###*
 * SDK版本限制判断
 * @param  {String} version 需要换算的版本号
 * @return {Boolean}         执行结果
###
limitDecision = ( limitVersion ) ->
  currectVersion = base.version
  # 匹配操作符和限制版本号
  temp = /^((\*|~|\^|>|<)=?)?([1-9]+(\.[0-9]+)+)?$/.exec limitVersion
  sign = temp[1]
  limitVersion = temp[3]
  limitMap =
    ###
      不匹配版本，通用
    ###
    '*': -> yes
    ###
      匹配版本满足一级和二级版本号相同，其余大于该版本，包括该版本
    ###
    '~': ->
      currectArray = currectVersion.split '.'
      limitArray = limitVersion.split '.'
      if currectArray[0] is limitArray[0] and currectArray[1] is limitArray[1]
        return versionConvert( currectVersion ) >= versionConvert limitVersion
      no
    ###
      匹配版本满足一级版本号相同，其余大于该版本，包括该版本
    ###
    '^': ->
      currectArray = currectVersion.split '.'
      limitArray = limitVersion.split '.'
      if currectArray[0] is limitArray[0]
        return versionConvert( currectVersion ) >= versionConvert limitVersion
      no
    ###
      匹配大于该版本的sdk
    ###
    '>': -> versionConvert( currectVersion ) > versionConvert limitVersion
    ###
      匹配大于该版本的sdk，包括该版本
    ###
    '>=': -> versionConvert( currectVersion ) >= versionConvert limitVersion
    ###
      匹配小于该版本的sdk，包括该版本
    ###
    '<=': -> versionConvert( currectVersion ) <= versionConvert( limitVersion )
    ###
      匹配小于该版本的sdk
    ###
    '<': -> versionConvert( currectVersion ) < versionConvert( limitVersion )

  if sign
    limitMap[ sign ]()
  else
    versionConvert( currectVersion ) is versionConvert limitVersion


###*
 * 调用app`s sdk
 * @param  {String} method 需要调用的app方法
 * @return {Boolean}       调用结果
###
sdk = ( method, data, callback )->
  ###
    app对应的sdk配置缺失
  ###
  return console.log "#{base.app}sdk没有此功能提供" unless has method
  methods = base.config[ method ]
  ###
    遍历方法配置
  ###
  for limitVersion,method of methods
    ###*
     * 判断版本是否符合
    ###
    if limitDecision limitVersion
      ###
        sdk为字符串，web或者sdk通过log通信
      ###
      if typeof method is 'string'
        search = searchJoin data
        if method[0] is '/' or method[...3] is 'http'
          location.href = method + search
        else
          console.log method + search
        return yes
      ###
        调用app注入的bridge调用appView
      ###
      if "[object Array]" is toString.call method
        if window.WebViewJavascriptBridge
          method.push data, callback
          window.WebViewJavascriptBridge.callHandler.apply window.WebViewJavascriptBridge, method
        else
          alert "native-bridge未加载"
        return yes
      ###
        为函数的时候执行函数，传入数据
      ###
      if typeof method is 'function'
        method data, callback
        return yes
  no


###*
 * 匹配在appMap配置内是否有sdk存在
 * @param  {String} sdkName 需要校验的sdk名
 * @return {Boolean}        true sdk存在并且版本匹配 false sdk不存在或存在但是版本不匹配
###
has = (sdkName) -> `sdkName in base.methods`


###*
 * 初始化
 * @return {[type]} [description]
###
init = ->
  temp =
    system: systemConfirm()
  ###*
   * 遍历sdk配置，匹配H5容器
  ###
  for app,opt of SDKConfig
    fn = opt.isMatch
    if fn
      if typeof fn is 'function' and fn()
        temp.app = app
        break
      if typeof fn is 'boolean' and fn
        temp.app = app
        break
    else if ua.indexOf( app ) isnt -1
      temp.app = app
      break
  ###*
   *
  ###
  if temp.app
    temp.version = SDKConfig[ temp.app ][ 'getVersion' ]()
    temp.system = systemConfirm()
    temp.config = SDKConfig[ temp.app ][ temp.system ] or {}
  else
    temp.app = 'web'
    temp.config = SDKConfig.web or {}
  temp

base = exports.base = init()
exports.sdk = sdk
exports.has = has
exports.gtVersion = (v) -> versionConvert( base.version ) >= versionConvert v
exports.ltVersion = (v) -> versionConvert( base.version ) < versionConvert v
