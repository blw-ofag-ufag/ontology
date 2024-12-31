document.addEventListener('DOMContentLoaded', async function () {
    const dataUrl = 'https://raw.githubusercontent.com/blw-ofag-ufag/ontology/main/mapping-tables/crops.json';
    const translationsUrl = './translations.json';
    const tableBody = document.querySelector('#cropsTable tbody');
    const languageSelector = document.getElementById('language');

    // Detect language from URL or default to 'de'
    const urlParams = new URLSearchParams(window.location.search);
    let lang = urlParams.get('lang') || 'de';
    languageSelector.value = lang;

    // Fetch and Apply Translations
    const translations = await fetchTranslations(translationsUrl);
    applyTranslations(lang, translations);

    // Update Language on Change
    languageSelector.addEventListener('change', function () {
        lang = this.value;
        urlParams.set('lang', lang);
        window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);
        applyTranslations(lang, translations);
        fetchData();  // Refresh table data
    });

    fetchData();

    // Fetch Crop Data and Populate Table
    function fetchData() {
        fetch(dataUrl)
            .then(response => response.json())
            .then(data => {
                tableBody.innerHTML = '';  // Clear table to avoid duplication
                data.forEach(item => {
                    const row = document.createElement('tr');

                    const idCell = document.createElement('td');
                    idCell.textContent = item['srppp-id'] || '';
                    row.appendChild(idCell);

                    const nameCell = document.createElement('td');
                    nameCell.textContent = item.label?.[lang]?.[0] || 'N/A';
                    row.appendChild(nameCell);

                    const commentCell = document.createElement('td');
                    commentCell.textContent = item.comment?.[lang] || 'N/A';
                    row.appendChild(commentCell);

                    const typeCell = document.createElement('td');
                    const type = item.type || '';
                    typeCell.textContent = type === 'crop' ? '🌱' : type === 'noncrop' ? '🚧' : '';
                    row.appendChild(typeCell);

                    tableBody.appendChild(row);
                });
            })
            .catch(error => console.error('Fehler beim Laden der Daten:', error));
    }

    // Fetch Translations from JSON
    async function fetchTranslations(url) {
        const response = await fetch(url);
        return response.json();
    }

    // Apply Translations to Page Elements
    function applyTranslations(lang, translations) {
        const t = translations[lang] || translations['de'];

        document.title = t.title;
        document.getElementById('titleHeading').textContent = t.title;
        document.getElementById('subtitle').textContent = t.subtitle;
        document.getElementById('searchInput').placeholder = t.search;
        document.getElementById('langLabel').textContent = t.language_label;

        const headers = t.columns;
        document.getElementById('col1').textContent = headers[0];
        document.getElementById('col2').textContent = headers[1];
        document.getElementById('col3').textContent = headers[2];
        document.getElementById('col4').textContent = headers[3];
    }
});
