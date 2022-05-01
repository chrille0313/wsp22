var popups = document.querySelectorAll('.popup');
var popup_triggers = document.querySelectorAll('.popup-trigger');

popup_triggers.forEach((trigger, index) => {
    trigger.addEventListener('click', () => {
        var popup = popups[index]
        popup.classList.add('visible');

        var close_button = popup.querySelector('.popup-close');
        close_button.addEventListener('click', () => {
            popup.classList.remove('visible');
        });
    });
});
