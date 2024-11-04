// 合并删除积分详情内容的脚本

// 处理不同的 URL 路径，根据不同 URL 重写相应内容
const url = $request.url;

// 删除指定路径的内容
if (url.includes('/api/v1/user/integral_details')) {
    // 删除积分详情内容，返回空的 "data" 对象
    let body = JSON.stringify({
      "msg": "获取成功",
      "data": {}
    });
    $done({ body });
} else {
    // 其他内容，按需处理
    // 示例：555.js 的原始内容，这里假设它的内容不需要重写，可以直接返回
    $done({});
}