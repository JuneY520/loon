
/*
桶汁影视 全套增强去广告（MITM版）
移除：开屏广告、弹窗广告、banner、活动、推荐广告等
递归清除广告字段，不留空白、不破坏布局
*/

let body = $response.body || "";
if (!body) return $done({});

try {
    let obj = JSON.parse(body);

    // 广告字段列表（覆盖全部推广字段）
    const adKeys = [
        "ad","ads","adlist","advert","advertlist","advertinfo",
        "banner","bannerlist",
        "popup","popupad","pop","popad",
        "recommend","recommendlist",
        "splash","openad","openadv","startpage",
        "activity","notice","event","marketing",
        "float","floatad","hotlist",
        "rollad","topad","midad","bottomad",
        "videoAd","beforePlayAd","pauseAd"
    ];

    // 统一转小写做判断
    const isAD = (key) => adKeys.includes(key.toLowerCase());

    // 递归清除
    function cleanAds(obj) {
        if (typeof obj !== "object" || obj === null) return;

        for (let key in obj) {
            try {
                if (isAD(key)) {
                    // 广告字段 → 清空数组或 null
                    obj[key] = Array.isArray(obj[key]) ? [] : null;
                } else if (typeof obj[key] === "object") {
                    cleanAds(obj[key]);
                }
            } catch (e) {}
        }
    }

    cleanAds(obj);

    $done({ body: JSON.stringify(obj) });

} catch (err) {
    console.log("Tongzhi Ad Remove Error: " + err);
    $done({});
}
"""