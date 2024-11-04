// 读取原始响应内容
let obj = JSON.parse($response.body);

// 保留 "msg"、"code" 以及 "data" 中的 "app_config" 部分（即整个 data）
obj = {
  msg: obj.msg,
  code: obj.code,
  data: {
    find_config: obj.data.find_config,
    history_config: obj.data.history_config
  }
};

// 返回修改后的响应内容
$done({ body: JSON.stringify(obj) });