/* ===========================
   MENU MOBILE
   =========================== */
const btnMenu = document.getElementById("btn-menu");
const menu = document.getElementById("menu-mobile");
const overlay = document.getElementById("overlay");
const btnFechar = document.querySelector("#menu-mobile .btn-fechar");

btnMenu.addEventListener("click", () => menu.classList.add("abrir-menu"));
overlay.addEventListener("click", () => menu.classList.remove("abrir-menu"));
if (btnFechar)
  btnFechar.addEventListener("click", () => menu.classList.remove("abrir-menu"));

document
  .querySelectorAll("#menu-mobile nav ul li a")
  .forEach((link) =>
    link.addEventListener("click", () => menu.classList.remove("abrir-menu"))
  );

/* ===========================
   TROCA DE IDIOMA PT / EN
   =========================== */
const langSwitch = document.getElementById("lang-switch");
const langLabel = document.getElementById("lang-label");
const htmlEl = document.documentElement;

function aplicarIdioma(lang) {
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const texto = lang === "en" ? el.dataset.en : el.dataset.pt;
    if (texto !== undefined) el.innerHTML = texto;
  });
  htmlEl.setAttribute("lang", lang === "en" ? "en" : "pt-br");
  // O botão mostra o idioma para o qual você VAI trocar
  langLabel.textContent = lang === "en" ? "PT" : "EN";
  localStorage.setItem("idioma", lang);
}

let idiomaAtual = localStorage.getItem("idioma") || "pt";
aplicarIdioma(idiomaAtual);

langSwitch.addEventListener("click", () => {
  idiomaAtual = idiomaAtual === "en" ? "pt" : "en";
  aplicarIdioma(idiomaAtual);
});

/* ===========================
   ANO AUTOMÁTICO NO RODAPÉ
   =========================== */
const ano = document.getElementById("ano");
if (ano) ano.textContent = new Date().getFullYear();
