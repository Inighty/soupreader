const String sourceLoginScriptBridgeJs = '''
function __srParseJsonMap(raw) {
  if (raw === null || raw === undefined) return {};
  if (typeof raw === 'string') {
    var t = String(raw).trim();
    if (!t) return {};
    try {
      var parsed = JSON.parse(t);
      return (parsed && typeof parsed === 'object') ? parsed : {};
    } catch (e) {
      return {};
    }
  }
  if (typeof raw === 'object') return raw;
  return {};
}

function __srToJavaMap(obj) {
  var m = (obj && typeof obj === 'object') ? obj : {};
  m.get = function(k) { return this[k]; };
  m.put = function(k, v) { this[k] = v; return v; };
  m.remove = function(k) {
    var v = this[k];
    try { delete this[k]; } catch (e) {}
    return v;
  };
  m.containsKey = function(k) {
    return Object.prototype.hasOwnProperty.call(this, k);
  };
  return m;
}

function __srHeaderArg(header) {
  if (header === null || header === undefined) return '';
  if (typeof header === 'string') return header;
  try {
    return JSON.stringify(header);
  } catch (e) {
    return String(header);
  }
}

function __srBuildHeadersProxy(rawHeaders) {
  var headers = __srParseJsonMap(rawHeaders);
  return {
    get: function(name) {
      var target = String(name || '').toLowerCase();
      var value = '';
      Object.keys(headers).forEach(function(k) {
        if (!value && String(k).toLowerCase() === target) {
          value = String(headers[k] || '');
        }
      });
      return value;
    },
    toString: function() {
      try {
        return JSON.stringify(headers);
      } catch (e) {
        return '';
      }
    }
  };
}

var source = {
  getLoginInfo: function() {
    return sendMessage('SourceGetLoginInfo', '{}') || '';
  },
  getLoginInfoMap: function() {
    return __srToJavaMap(__srParseJsonMap(source.getLoginInfo()));
  },
  getLoginHeader: function() {
    return sendMessage('SourceGetLoginHeader', '{}') || '';
  },
  getLoginHeaderMap: function() {
    return __srToJavaMap(__srParseJsonMap(source.getLoginHeader()));
  },
  putLoginHeader: function(value) {
    return sendMessage('SourcePutLoginHeader', JSON.stringify({value: value}));
  },
  removeLoginHeader: function() {
    return sendMessage('SourceRemoveLoginHeader', '{}');
  },
  log: function(message) {
    return sendMessage('SourceLog', JSON.stringify({message: String(message || '')}));
  }
};

var java = {
  ajax: async function(url, header) {
    var raw = await sendMessage('JavaAjax', JSON.stringify({
      url: String(url || ''),
      header: __srHeaderArg(header)
    }));
    return raw === null || raw === undefined ? '' : String(raw);
  },
  connect: async function(url, header) {
    var raw = await sendMessage('JavaConnect', JSON.stringify({
      url: String(url || ''),
      header: __srHeaderArg(header)
    }));
    var parsed = {};
    try {
      parsed = JSON.parse(String(raw || '{}'));
    } catch (e) {
      parsed = {};
    }
    var bodyText = String(parsed.body || '');
    var statusCode = Number(parsed.code || 0);
    var statusMessage = String(parsed.message || '');
    var finalUrl = String(parsed.url || String(url || ''));
    var headerProxy = __srBuildHeadersProxy(parsed.headers || {});
    return {
      body: function() { return bodyText; },
      code: function() { return statusCode; },
      message: function() { return statusMessage; },
      url: function() { return finalUrl; },
      headers: function() { return headerProxy; },
      isSuccessful: function() { return statusCode >= 200 && statusCode < 300; },
      toString: function() { return bodyText; }
    };
  },
  randomUUID: function() {
    return sendMessage('JavaRandomUUID', '{}');
  },
  timeFormatUTC: function(timestamp, pattern, offset) {
    return sendMessage('JavaTimeFormatUTC', JSON.stringify({
      timestamp: timestamp,
      pattern: pattern,
      offset: offset
    }));
  }
};
''';
