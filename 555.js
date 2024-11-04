// Loon 脚本：拦截导航栏请求并返回空内容

// 判断是否为特定导航栏请求
if ($request.url.includes("/api/v1/activities/invite/notices")) {
  // 拦截请求，返回空的 JSON 响应以删除导航栏内容
  $done({
    response: {
      status: 200,
      headers: { "Content-Type": "application/json" },
      body: "{}"
    }
  });
} else {
  // 直接放行其他请求
  $done({});
}