// 读取原始响应内容
let obj = JSON.parse($response.body);

// 修改数据，只保留 find_config 和 history_config
obj.data = {
  find_config: obj.data.find_config,
  history_config: obj.data.history_config,
};

// 返回修改后的响应内容
$done({ body: JSON.stringify(obj) });