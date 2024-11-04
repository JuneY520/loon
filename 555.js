// 获取请求的 URL
const url = $request.url;
let body;

// 根据不同的请求地址执行不同的重写逻辑
if (url.includes('/api/v1/user/integral_details')) {
    // 删除积分详情内容，返回空的 "data" 对象
    body = JSON.stringify({
        "msg": "获取成功",
        "data": {}
    });
} else if (url.includes('/api/v1/activities/invite/notices')) {
    // 删除邀请通知内容，返回空的 "list" 数组
    body = JSON.stringify({
        "msg": "获取成功",
        "data": {
            "list": [],
            "pageSize": 1,
            "total": 0,
            "page": 1
        }
    });
} else if (url.includes('/api/v1/home/data')) {
    // 其他请求地址的逻辑，例如主页数据
    body = JSON.stringify({
        "msg": "获取成功",
        "data": {
            "message": "主页数据已被删除"
        }
    });
}

// 如果有内容需要修改，则返回修改后的 body，否则直接结束请求
if (body) {
    $done({ body });
} else {
    $done({});
}