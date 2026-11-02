document.documentElement.classList.add('js');
const toc = document.getElementById('toc');
document.querySelectorAll('article h2').forEach((heading, i) => {
  if (!heading.id) heading.id = `section-${i + 1}`;
  const a = document.createElement('a');
  a.href = `#${heading.id}`; a.textContent = heading.textContent;
  toc?.appendChild(a);
});
document.querySelectorAll('div.highlighter-rouge').forEach(block => {
  const button = document.createElement('button');
  button.className = 'copy-code'; button.type = 'button'; button.textContent = '코드 복사';
  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(block.querySelector('code').textContent);
      button.textContent = '복사 완료';
    } catch { button.textContent = '코드를 선택해 복사하세요'; }
    setTimeout(() => { button.textContent = '코드 복사'; }, 2000);
  });
  block.appendChild(button);
});
const dialog = document.createElement('dialog');
const close = document.createElement('button'); close.textContent = '닫기 ×'; close.type = 'button';
const enlarged = document.createElement('img');
dialog.append(close, enlarged); document.body.appendChild(dialog);
close.addEventListener('click', () => dialog.close());
dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
document.querySelectorAll('article img').forEach(img => {
  img.loading = 'lazy'; img.decoding = 'async'; img.classList.add('zoomable');
  const wrapper = document.createElement('a'); wrapper.href = img.src; wrapper.setAttribute('aria-label',`${img.alt} 크게 보기`);
  img.parentNode.insertBefore(wrapper,img); wrapper.appendChild(img);
  wrapper.addEventListener('click', event => {
    if (!dialog.showModal || event.ctrlKey || event.metaKey) return;
    event.preventDefault(); enlarged.src = img.src; enlarged.alt = img.alt; dialog.showModal();
  });
});
