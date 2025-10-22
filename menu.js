
let btnMenu = document.getElementById('btn-menu')
let menu = document.getElementById('menu-mobile')
let overlay = document.getElementById('overlay-menu')

btnMenu.addEventListener('click',()=>{
    menu.classList.add('abrir-menu')
})

menu.addEventListener('click',()=>{
    menu.classList.remove('abrir-menu')
})

overlay.addEventListener('click',()=>{
    menu.classList.remove('abrir-menu')
})

// Seleciona todos os links do menu mobile
const linksMobile = document.querySelectorAll('#menu-mobile nav ul li a');

linksMobile.forEach(link => {
    link.addEventListener('click', () => {
        menu.classList.remove('abrir-menu'); // Fecha menu
    });
});
