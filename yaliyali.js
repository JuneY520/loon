// 仅当 URL 匹配特定请求时执行
if ($request.url.includes("/v6/app_config")) {
  // 获取响应内容
  let body = $response.body;
  
  // 解析 JSON
  let obj = JSON.parse(body);

  // 删除不需要的字段
  if (obj.data) {
    if (obj.data.dm_config) {
      delete obj.data.dm_config.top_content; // 删除“文明发送弹幕”内容
    }
    if (obj.data.comment_config) {
      delete obj.data.comment_config; // 删除“官方提醒”内容
    }
    if (obj.data.find_config) {
      delete obj.data.find_config; // 删除“留言”配置
    }
    if (obj.data.modules_config && obj.data.modules_config.find) {
      delete obj.data.modules_config.find; // 删除底部导航栏中的“留言”按钮
    }
    if (obj.data.img_config && obj.data.img_config.splash_img) {
      delete obj.data.img_config.splash_img; // 删除开屏广告图片
    }
  }

  // 转回 JSON 字符串
  body = JSON.stringify(obj);

  // 返回修改后的响应
  $done({ body });
} else {
  // 直接放行其他请求
  $done({});
}