/**
 * Hans Dither Backend - JavaScript
 * 
 * Einfaches Formular-Handling und AJAX für bessere UX.
 */

document.addEventListener('DOMContentLoaded', function() {
    // Formular-Validierung
    const forms = document.querySelectorAll('.form');
    
    forms.forEach(form => {
        form.addEventListener('submit', function(e) {
            // PIN-Feld Validierung (4 Ziffern)
            const pinInput = form.querySelector('input[name="pin"]');
            if (pinInput) {
                const pin = pinInput.value.trim();
                if (!/^\d{4}$/.test(pin)) {
                    e.preventDefault();
                    alert('Bitte gib eine 4-stellige PIN ein (nur Ziffern 0-9)');
                    pinInput.focus();
                    return;
                }
            }
            
            // UID-Feld Validierung
            const uidInput = form.querySelector('input[name="uid"]');
            if (uidInput && uidInput.value.trim() === '') {
                e.preventDefault();
                alert('Bitte gib eine UID ein');
                uidInput.focus();
                return;
            }
            
            // Datei-Felder Validierung
            const pdiInput = form.querySelector('input[name="pdi"]');
            const jsonInput = form.querySelector('input[name="json"]');
            
            if (pdiInput && !pdiInput.value) {
                e.preventDefault();
                alert('Bitte wähle eine PDI-Datei aus');
                return;
            }
            
            if (jsonInput && !jsonInput.value) {
                e.preventDefault();
                alert('Bitte wähle eine JSON-Datei aus');
                return;
            }
        });
    });
    
    // Upload-Formular: Fortschritt anzeigen
    const uploadForm = document.querySelector('form[action*="upload.php"]');
    if (uploadForm) {
        const submitButton = uploadForm.querySelector('button[type="submit"]');
        const originalButtonText = submitButton ? submitButton.textContent : 'Hochladen';
        
        uploadForm.addEventListener('submit', function(e) {
            if (submitButton) {
                submitButton.disabled = true;
                submitButton.textContent = 'Hochladen...';
            }
            
            // Formular wird normal gesendet, kein AJAX (für Datei-Uploads einfacher)
        });
    }
    
    // Fehlerbehandlung: URL-Parameter "error" anzeigen
    const urlParams = new URLSearchParams(window.location.search);
    const error = urlParams.get('error');
    
    if (error) {
        let errorMessage = 'Ein Fehler ist aufgetreten';
        
        switch(error) {
            case 'uid_exists':
                errorMessage = 'UID bereits verknüpft. Bitte melde dich an.';
                break;
            case 'invalid':
                errorMessage = 'UID oder PIN ungültig.';
                break;
            case 'locked':
                errorMessage = 'Zu viele Fehlversuche. Bitte in 5 Minuten erneut versuchen.';
                break;
        }
        
        // Falls kein Error-Element existiert, erstellen
        if (!document.querySelector('.error')) {
            const container = document.querySelector('.container');
            if (container) {
                const errorElement = document.createElement('div');
                errorElement.className = 'error';
                errorElement.textContent = errorMessage;
                container.insertBefore(errorElement, container.firstChild.nextSibling);
            }
        }
    }
    
    // Erfolgreiches Pairing/Login: Weiterleitung
    const success = urlParams.get('success');
    if (success === 'true') {
        const container = document.querySelector('.container');
        if (container) {
            const successElement = document.createElement('div');
            successElement.className = 'success';
            successElement.textContent = 'Erfolgreich angemeldet!';
            container.insertBefore(successElement, container.firstChild.nextSibling);
        }
    }
});

// Hilfsfunktion: JSON abrufen und anzeigen (für API-Tests)
function fetchJson(url, callback) {
    fetch(url, {
        headers: {
            'Accept': 'application/json'
        }
    })
    .then(response => response.json())
    .then(data => callback(null, data))
    .catch(error => callback(error, null));
}
