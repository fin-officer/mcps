// Skrypt dla interfejsu Ollama Server

document.addEventListener('DOMContentLoaded', function() {
    // Elementy DOM
    const chatContainer = document.getElementById('chatContainer');
    const queryForm = document.getElementById('queryForm');
    const promptInput = document.getElementById('promptInput');
    const temperatureInput = document.getElementById('temperatureInput');
    const temperatureValue = document.getElementById('temperatureValue');
    const maxTokensInput = document.getElementById('maxTokensInput');
    const maxTokensValue = document.getElementById('maxTokensValue');
    const modelSwitchBtn = document.getElementById('modelSwitchBtn');
    const modelSwitcher = document.getElementById('modelSwitcher');
    const closeModalBtn = document.querySelector('.close');
    const modelList = document.getElementById('modelList');

    // Aktualizacja wartości parametrów
    temperatureInput.addEventListener('input', function() {
        temperatureValue.textContent = this.value;
    });

    maxTokensInput.addEventListener('input', function() {
        maxTokensValue.textContent = this.value;
    });

    // Obsługa modalu z wyborem modelu
    modelSwitchBtn.addEventListener('click', function() {
        fetchModels();
        modelSwitcher.style.display = 'block';
    });

    closeModalBtn.addEventListener('click', function() {
        modelSwitcher.style.display = 'none';
    });

    window.addEventListener('click', function(event) {
        if (event.target === modelSwitcher) {
            modelSwitcher.style.display = 'none';
        }
    });

    // Pobieranie listy modeli
    function fetchModels() {
        modelList.innerHTML = '<p>Ładowanie dostępnych modeli...</p>';

        fetch('/models')
            .then(response => response.json())
            .then(data => {
                if (data.models && data.models.length > 0) {
                    renderModels(data.models);
                } else {
                    modelList.innerHTML = '<p>Brak dostępnych modeli</p>';
                }
            })
            .catch(error => {
                console.error('Błąd pobierania modeli:', error);
                modelList.innerHTML = '<p class="error">Błąd pobierania listy modeli</p>';
            });
    }

    // Renderowanie listy modeli
    function renderModels(models) {
        modelList.innerHTML = '';

        models.forEach(model => {
            const modelItem = document.createElement('div');
            modelItem.className = 'model-item' + (model.current ? ' active' : '');

            const modelInfo = model.info || { size: '?', description: 'Brak informacji' };

            modelItem.innerHTML = `
                <div>
                    <div class="model-name">${model.name}</div>
                    <div class="model-details">${modelInfo.size} - ${modelInfo.description}</div>
                </div>
                <div class="model-actions">
                    <button class="btn ${model.current ? 'btn-primary' : ''}" data-model="${model.name}">
                        ${model.current ? 'Aktywny' : 'Wybierz'}
                    </button>
                </div>
            `;

            modelList.appendChild(modelItem);

            // Dodanie obsługi zdarzenia dla przycisku
            const button = modelItem.querySelector('button');
            button.addEventListener('click', function() {
                switchModel(this.dataset.model);
            });
        });
    }

    // Przełączanie modelu
    function switchModel(modelName) {
        const formData = new FormData();
        formData.append('model_name', modelName);

        fetch('/switch_model', {
            method: 'POST',
            body: formData,
            headers: {
                'X-Requested-With': 'XMLHttpRequest'
            }
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                // Odśwież stronę po przełączeniu modelu
                window.location.reload();
            } else {
                alert('Błąd podczas przełączania modelu: ' + (data.error || 'Nieznany błąd'));
            }
        })
        .catch(error => {
            console.error('Błąd podczas przełączania modelu:', error);
            alert('Błąd podczas przełączania modelu');
        });
    }

    // Obsługa formularza zapytania
    if (queryForm) {
        queryForm.addEventListener('submit', function(e) {
            e.preventDefault();

            const prompt = promptInput.value.trim();
            if (!prompt) return;

            const temperature = temperatureInput.value;
            const maxTokens = maxTokensInput.value;

            // Dodaj wiadomość użytkownika do czatu
            addUserMessage(prompt);

            // Wyczyść pole wprowadzania
            promptInput.value = '';

            // Pokaż wskaźnik ładowania
            const loadingMessage = addLoadingMessage();

            // Wyślij zapytanie do API
            const formData = new FormData();
            formData.append('prompt', prompt);
            formData.append('temperature', temperature);
            formData.append('max_tokens', maxTokens);

            fetch('/ask', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                // Usuń wskaźnik ładowania
                loadingMessage.remove();

                if (data.error) {
                    addErrorMessage(data.error);
                } else {
                    addModelMessage(data.response);
                }

                // Przewiń do najnowszej wiadomości
                chatContainer.scrollTop = chatContainer.scrollHeight;
            })
            .catch(error => {
                // Usuń wskaźnik ładowania
                loadingMessage.remove();

                console.error('Błąd zapytania:', error);
                addErrorMessage('Wystąpił błąd podczas komunikacji z serwerem');

                // Przewiń do najnowszej wiadomości
                chatContainer.scrollTop = chatContainer.scrollHeight;
            });
        });
    }

    // Funkcje do dodawania wiadomości do czatu
    function addUserMessage(text) {
        const welcomeMessage = document.querySelector('.welcome-message');
        if (welcomeMessage) {
            welcomeMessage.remove();
        }

        const messageDiv = document.createElement('div');
        messageDiv.className = 'chat-message';
        messageDiv.innerHTML = `
            <div class="message-user">
                <p>${escapeHtml(text)}</p>
            </div>
        `;

        chatContainer.appendChild(messageDiv);
        chatContainer.scrollTop = chatContainer.scrollHeight;

        return messageDiv;
    }

    function addModelMessage(text) {
        const messageDiv = document.createElement('div');
        messageDiv.className = 'chat-message';

        // Konwertuj tekst na HTML z zachowaniem formatowania kodu
        const formattedText = formatText(text);

        messageDiv.innerHTML = `
            <div class="message-model">
                ${formattedText}
            </div>
        `;

        chatContainer.appendChild(messageDiv);
        return messageDiv;
    }

    function addLoadingMessage() {
        const messageDiv = document.createElement('div');
        messageDiv.className = 'chat-message loading-message';
        messageDiv.innerHTML = `
            <div class="message-model">
                <p>Generowanie odpowiedzi...</p>
            </div>
        `;

        chatContainer.appendChild(messageDiv);
        chatContainer.scrollTop = chatContainer.scrollHeight;

        return messageDiv;
    }

    function addErrorMessage(text) {
        const messageDiv = document.createElement('div');
        messageDiv.className = 'chat-message error-message';
        messageDiv.innerHTML = `
            <div class="message-model">
                <p style="color: var(--error-color);">Błąd: ${escapeHtml(text)}</p>
            </div>
        `;

        chatContainer.appendChild(messageDiv);
        return messageDiv;
    }

    // Pomocnicze funkcje formatowania
    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    function formatText(text) {
        // Zastąp bloki kodu
        text = text.replace(/```([a-z]*)([\s\S]*?)```/g, function(match, language, code) {
            return `<pre><code class="language-${language || 'plaintext'}">${escapeHtml(code.trim())}</code></pre>`;
        });

        // Zastąp jednoliniowe bloki kodu
        text = text.replace(/`([^`]+)`/g, '<code>$1</code>');

        // Zastąp nowe linie
        text = text.replace(/\n/g, '<br>');

        return text;
    }

    // Inicjalizacja strony
    if (chatContainer.querySelector('.welcome-message')) {
        promptInput.focus();
    }
});