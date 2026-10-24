document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("nav a").forEach(link => {
    if (new URL(link.href).pathname === location.pathname) link.classList.add("active");
  });
  const marker = document.querySelector("[data-realtime]");
  if (!marker) return;
  let socket, timer;
  const connect = () => {
    socket = new WebSocket(`${location.protocol === "https:" ? "wss" : "ws"}://${location.host}/cable`, ["actioncable-v1-json"]);
    socket.onopen = () => socket.send(JSON.stringify({command: "subscribe", identifier: JSON.stringify({channel: "HrUpdatesChannel"})}));
    socket.onmessage = event => {
      const data = JSON.parse(event.data);
      if (data.type === "confirm_subscription") marker.textContent = "● Đang kết nối trực tiếp";
      if (data.message) marker.textContent = "● Có dữ liệu mới — tải lại trang để cập nhật";
    };
    socket.onclose = () => { marker.textContent = "○ Đang kết nối lại…"; timer = setTimeout(connect, 5000); };
  };
  connect();
  window.addEventListener("pagehide", () => { clearTimeout(timer); socket.onclose = null; socket.close(); });
});
