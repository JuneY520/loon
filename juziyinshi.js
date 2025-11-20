/**************************************
 * 桶汁影视 - 增强去广告脚本
 * 支持接口：
 * 1. /api/v2/config/getConfigList.do
 * 2. /api/ex/v3/security/tag/list
 * 自动清理广告字段 / 不破坏正常分类
 **************************************/

let body = $response.body || "";
if (!body) return $done({});

try {
    const url = $request.url;
    let obj = JSON.parse(body);

    // 广告字段列表（覆盖绝大部分推广字段）
    const adKeys = [
        "ad","ads","adlist","advert","advertlist","advertinfo",
        "banner","bannerlist",
        "popup","popupad","pop","popad",
        "recommend","recommendlist",
        "splash","openad","openadv","startpage",
        "activity","notice","event","marketing",
        "float","floatad","hotlist",
        "rollad","topad","midad","bottomad",
        "videoAd","beforePlayAd","pauseAd",
        "extAd","adConfig","adInfo"
    ];

    const isAD = (key) => adKeys.includes(key.toLowerCase());

    // 递归清理广告字段
    function cleanAds(obj) {
        if (typeof obj !== "object" || obj === null) return;

        for (let key in obj) {
            try {
                if (isAD(key)) {
                    // 广告字段 → 清空数组或设置 null
                    obj[key] = Array.isArray(obj[key]) ? [] : null;
                } else if (typeof obj[key] === "object") {
                    cleanAds(obj[key]);
                }
            } catch (e) {}
        }
    }

    // 处理 getConfigList & tag/list
    if (
        url.includes("/api/v2/config/getConfigList.do") ||
        url.includes("/api/ex/v3/security/tag/list")
    ) {
        cleanAds(obj);
    }

    $done({ body: JSON.stringify(obj) });

} catch (err) {
    console.log("Tongzhi Ad Remove Enhanced Error: " + err);
    $done({});
}