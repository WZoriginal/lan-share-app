const links = [
  { name: "共享文件目录", url: "files/" },
  { name: "使用说明", url: "README.md" },
];

let files = [];

const shareUrlInput = document.querySelector("#shareUrl");
const copyUrlButton = document.querySelector("#copyUrl");
const copyHint = document.querySelector("#copyHint");
const linkList = document.querySelector("#linkList");
const linkCount = document.querySelector("#linkCount");
const fileTable = document.querySelector("#fileTable");
const fileSearch = document.querySelector("#fileSearch");
const uploadButton = document.querySelector("#uploadButton");
const refreshButton = document.querySelector("#refreshButton");
const fileUpload = document.querySelector("#fileUpload");
const uploadStatus = document.querySelector("#uploadStatus");
const clock = document.querySelector("#clock");
const noticeText = document.querySelector("#noticeText");
const noticeForm = document.querySelector("#noticeForm");
const noticeInput = document.querySelector("#noticeInput");
const editNotice = document.querySelector("#editNotice");
const cancelNotice = document.querySelector("#cancelNotice");

const savedNotice = localStorage.getItem("lan-share-notice");
if (savedNotice) {
  noticeText.textContent = savedNotice;
}

function updateShareUrl() {
  shareUrlInput.value = window.location.href;
}

function renderLinks() {
  linkCount.textContent = links.length.toString();
  linkList.innerHTML = links
    .map(
      (link) => `
        <li>
          <a href="${link.url}" target="_blank" rel="noreferrer">
            <strong>${link.name}</strong>
            <span>打开</span>
          </a>
        </li>
      `,
    )
    .join("");
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;",
  })[char]);
}

function renderFiles(keyword = "") {
  const normalized = keyword.trim().toLowerCase();
  const visibleFiles = files.filter((file) => {
    const content = `${file.name} ${file.type} ${file.path}`.toLowerCase();
    return content.includes(normalized);
  });

  if (visibleFiles.length === 0) {
    fileTable.innerHTML = `
      <tr>
        <td colspan="5" class="empty-state">当前没有匹配的共享文件。</td>
      </tr>
    `;
    return;
  }

  fileTable.innerHTML = visibleFiles
    .map(
      (file) => `
        <tr>
          <td><strong>${escapeHtml(file.name)}</strong></td>
          <td>${escapeHtml(file.type)}</td>
          <td>${escapeHtml(file.size)}</td>
          <td>${escapeHtml(file.updated)}</td>
          <td class="record-actions">
            <button class="table-delete" type="button" data-path="${escapeHtml(file.path)}">删除</button>
          </td>
        </tr>
      `,
    )
    .join("");
}

async function loadFiles() {
  try {
    const response = await fetch("api/files", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    files = data.files || [];
    renderFiles(fileSearch.value);
    uploadStatus.textContent = `已加载 ${files.length} 个共享文件。`;
  } catch (error) {
    uploadStatus.textContent = `读取共享文件失败：${error.message}`;
    renderFiles(fileSearch.value);
  }
}

async function deleteSharedFile(path) {
  const file = files.find((item) => item.path === path);
  const name = file ? file.name : path;
  if (!window.confirm(`确定删除“${name}”？删除后文件会从共享目录移除。`)) return;

  uploadStatus.textContent = "正在删除文件...";
  try {
    const response = await fetch("api/delete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path }),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);

    files = data.files || [];
    renderFiles(fileSearch.value);
    uploadStatus.textContent = `已删除“${data.deleted.name}”。`;
  } catch (error) {
    uploadStatus.textContent = `删除失败：${error.message}`;
  }
}

async function uploadFiles(selectedFiles) {
  if (selectedFiles.length === 0) return;

  const formData = new FormData();
  selectedFiles.forEach((file) => {
    formData.append("files", file, file.name);
  });

  uploadButton.disabled = true;
  refreshButton.disabled = true;
  uploadStatus.textContent = `正在上传 ${selectedFiles.length} 个文件...`;

  try {
    const response = await fetch("api/upload", {
      method: "POST",
      body: formData,
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);

    files = data.files || [];
    renderFiles(fileSearch.value);
    uploadStatus.textContent = `已上传 ${data.uploaded.length} 个文件。`;
  } catch (error) {
    uploadStatus.textContent = `上传失败：${error.message}`;
  } finally {
    uploadButton.disabled = false;
    refreshButton.disabled = false;
    fileUpload.value = "";
  }
}

function updateClock() {
  const now = new Date();
  clock.textContent = now.toLocaleString("zh-CN", {
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

copyUrlButton.addEventListener("click", async () => {
  await navigator.clipboard.writeText(shareUrlInput.value);
  copyHint.textContent = "访问地址已复制。";
  window.setTimeout(() => {
    copyHint.textContent = "启动服务后，其他设备可用同一局域网内的访问地址打开。";
  }, 1800);
});

fileSearch.addEventListener("input", (event) => {
  renderFiles(event.target.value);
});

fileTable.addEventListener("click", (event) => {
  const button = event.target.closest(".table-delete");
  if (!button) return;
  deleteSharedFile(button.dataset.path);
});

uploadButton.addEventListener("click", () => {
  fileUpload.click();
});

refreshButton.addEventListener("click", loadFiles);

fileUpload.addEventListener("change", async () => {
  await uploadFiles(Array.from(fileUpload.files));
});

editNotice.addEventListener("click", () => {
  noticeInput.value = noticeText.textContent.trim();
  noticeText.hidden = true;
  noticeForm.hidden = false;
  noticeInput.focus();
});

cancelNotice.addEventListener("click", () => {
  noticeForm.hidden = true;
  noticeText.hidden = false;
});

noticeForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const value = noticeInput.value.trim();
  if (!value) return;
  noticeText.textContent = value;
  localStorage.setItem("lan-share-notice", value);
  noticeForm.hidden = true;
  noticeText.hidden = false;
});

updateShareUrl();
renderLinks();
loadFiles();
updateClock();
window.setInterval(updateClock, 30_000);
