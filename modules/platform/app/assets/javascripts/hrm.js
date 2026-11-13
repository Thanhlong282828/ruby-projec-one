document.addEventListener("DOMContentLoaded", () => {
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

// Only edit form rows locally. Totals and authorization remain server-side.
document.addEventListener("click", event => {
  const add = event.target.closest("[data-add-purchase-line]");
  const remove = event.target.closest("[data-remove-purchase-line]");
  const section = (add || remove)?.closest("[data-purchase-lines]");
  if (!section) return;
  const list = section.querySelector("[data-purchase-line-list]");
  const feedback = section.querySelector("[data-purchase-line-feedback]");
  if (remove) {
    remove.closest(".purchase-line").remove();
    section.querySelector("[data-add-purchase-line]").focus();
    feedback.textContent = "Đã bỏ dòng khỏi bản nháp đang nhập. Bấm lưu để áp dụng.";
    return;
  }
  const rows = [...list.querySelectorAll(".purchase-line")];
  if (rows.length >= 50) { feedback.textContent = "Tối đa 50 dòng hàng."; return; }
  const index = Math.max(-1, ...rows.map(row => Number(row.dataset.lineIndex))) + 1;
  const row = section.querySelector("template").content.firstElementChild.cloneNode(true);
  row.dataset.lineIndex = String(index);
  row.querySelectorAll("input,label").forEach(element => {
    ["name", "id", "for"].forEach(attribute => {
      if (element.hasAttribute(attribute)) element.setAttribute(attribute, element.getAttribute(attribute).replaceAll("__INDEX__", String(index)));
    });
  });
  list.append(row);
  row.querySelector("input").focus();
  feedback.textContent = `Đã thêm dòng hàng. Hiện có ${rows.length + 1} dòng.`;
});
