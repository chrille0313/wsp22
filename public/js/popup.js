var popups = document.querySelectorAll('.popup');
var popup_triggers = document.querySelectorAll('.popup-trigger');

popup_triggers.forEach((trigger, index) => {
    trigger.addEventListener('click', (e) => {
        var popup = popups[index]
        popup.classList.add('visible');

        var close_button = popup.querySelector('.popup-close');
        close_button.addEventListener('click', (e) => {
            popup.classList.remove('visible');
        });
    });
});
