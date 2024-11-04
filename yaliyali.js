// 读取原始响应内容
let obj = JSON.parse($response.body);

// 放行 weekday_video_list 请求
if ($request.url.includes("weekday_video_list")) {
    // 直接返回原始响应
    $done({ body: $response.body });
}

// 如果需要对其他请求进行修改，可以在这里添加逻辑
// 例如，保留底部导航栏和历史记录配置
obj.data = {
    find_config: {
        bottom_nav_name: obj.data.find_config.bottom_nav_name // 保留底部导航栏名称
    },
    history_config: obj.data.history_config // 保留历史记录配置
};

// 返回修改后的响应内容
$done({ body: JSON.stringify(obj) });