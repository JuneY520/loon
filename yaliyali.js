// 读取原始响应内容
let obj = JSON.parse($response.body);

// 只保留导航栏显示配置和历史记录配置
obj.data = {
  find_config: {
    bottom_nav_name: obj.data.find_config.bottom_nav_name // 保留底部导航栏名称
  },
  history_config: obj.data.history_config // 保留历史记录配置
};

// 返回修改后的响应内容
$done({ body: JSON.stringify(obj) });