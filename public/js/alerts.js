var alertContainer = document.querySelector("#alert-container")

function fadeOut(target) {
    target.classList.add("fadeOut");
    var fadeDuration = parseFloat(window.getComputedStyle(target).getPropertyValue("transition-duration")) * 1000;

    setTimeout(function(){
        target.remove();
    }, fadeDuration);
}

function displayNotification(notification, displayDuration) {
    setTimeout(function(){
        fadeOut(notification)
    }, displayDuration);
}

function addNotification(type, message) {
    let types = {
        "info": "info",
        "success": "check_circle",
        "warning": "error_outline",
        "error": "cancel"
    };
      
    if (!types.hasOwnProperty(type)) { return false; }
    
    let notification = document.createElement("div");
    notification.classList.add("alert", type);
    
    let span = document.createElement("span");
    span.classList.add("icon", "material-icons-outlined");
    span.appendChild(document.createTextNode(types[type]));

    let p = document.createElement("p");
    p.appendChild(document.createTextNode(message));
    
    let button = document.createElement("button");
    button.classList.add("material-icons-outlined");
    button.appendChild(document.createTextNode('close'));
    button.addEventListener("click", function(e) { fadeOut(notification) });


    notification.appendChild(span);
    notification.appendChild(p);
    notification.appendChild(button);

    alertContainer.appendChild(notification);

    displayNotification(notification, 5000);

    return true;
}

window.onload = function() {
    var alerts = alertContainer.querySelectorAll('.alert');
    for (let i = 0; i < alerts.length; i++) {
        displayNotification(alerts[i], 5000);
    }
};