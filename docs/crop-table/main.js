// Embedded translations (instead of fetching from a JSON file)
const translations = {
    "de": {
        "title": "🌱 Kulturentabelle",
        "subtitle": "Hier findest du die Liste der Kulturen des Bundesamtes für Landwirtschaft BLW. Diese Liste ist <i>fast</i> komplett. Das tatsächliche File mit den Daten liegt auf <a href='https://github.com/blw-ofag-ufag/ontology/blob/main/mapping-tables/crops.json'>GitHub</a>.",
        "search": "🔍 Durchsuche nach Name, Kommentar etc.",
        "columns": ["ID", "Name", "Kommentare", "Typ"],
        "language_label": ""
    },
    "fr": {
        "title": "🌱 Tableau des Cultures",
        "subtitle": "Voici la liste des cultures de l'Office fédéral de l'agriculture OFAG. Cette liste est <i>presque</i> complète. Le fichier réel avec les données est disponible sur <a href='https://github.com/blw-ofag-ufag/ontology/blob/main/mapping-tables/crops.json'>GitHub</a>.",
        "search": "🔍 Rechercher par nom, commentaire, etc.",
        "columns": ["ID", "Nom", "Commentaires", "Type"],
        "language_label": ""
    },
    "it": {
        "title": "🌱 Tabella delle Colture",
        "subtitle": "Qui trovi l'elenco delle colture dell'Ufficio federale dell'agricoltura UFAG. Questo elenco è <i>quasi</i> completo. Il file effettivo con i dati si trova su <a href='https://github.com/blw-ofag-ufag/ontology/blob/main/mapping-tables/crops.json'>GitHub</a>.",
        "search": "🔍 Cerca per nome, commento, ecc.",
        "columns": ["ID", "Nome", "Commenti", "Tipo"],
        "language_label": ""
    },
    "en": {
        "title": "🌱 Crops Table",
        "subtitle": "Here you can find the list of crops from the Federal Office for Agriculture FOAG. This list is <i>almost</i> complete. The actual file with data is available on <a href='https://github.com/blw-ofag-ufag/ontology/blob/main/mapping-tables/crops.json'>GitHub</a>.",
        "search": "🔍 Search by name, comment, etc.",
        "columns": ["ID", "Name", "Comments", "Type"],
        "language_label": ""
    }
};


// Detect language from URL or default to 'de'
const urlParams = new URLSearchParams(window.location.search);
let lang = urlParams.get('lang') || 'de';
document.getElementById('language').value = lang;

// Apply Translations to Static Page Elements
function applyTranslations(lang) {
    const t = translations[lang] || translations['de'];

    document.title = t.title;
    document.getElementById('titleHeading').textContent = t.title;
    document.getElementById('langLabel').textContent = t.language_label;
    document.getElementById('searchInput').placeholder = t.search;

    // Safely insert subtitle with HTML (including <i> and <a> tags)
    document.getElementById('subtitle').innerHTML = t.subtitle;

    const headers = t.columns;
    document.getElementById('col1').textContent = headers[0];
    document.getElementById('col2').textContent = headers[1];
    document.getElementById('col3').textContent = headers[2];
    document.getElementById('col4').textContent = headers[3];
}


// Fetch Crop Data and Populate Table
function fetchData() {
    const dataUrl = 'https://raw.githubusercontent.com/blw-ofag-ufag/ontology/main/mapping-tables/crops.json';
    const tableBody = document.querySelector('#cropsTable tbody');

    fetch(dataUrl)
        .then(response => response.json())
        .then(data => {
            tableBody.innerHTML = '';  // Clear table before inserting new rows
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

// Sort Table by Column
function sortTable(columnIndex) {
    const table = document.getElementById('cropsTable');
    const rows = Array.from(table.rows).slice(1);
    const direction = table.dataset.sortDirection === 'asc' ? 'desc' : 'asc';
    table.dataset.sortDirection = direction;

    rows.sort((a, b) => 
        a.cells[columnIndex].textContent.localeCompare(b.cells[columnIndex].textContent) 
        * (direction === 'asc' ? 1 : -1)
    );

    const tableBody = table.querySelector('tbody');
    tableBody.innerHTML = '';
    rows.forEach(row => tableBody.appendChild(row));
}

// Filter/Search Functionality
document.getElementById('searchInput').addEventListener('input', function() {
    const filter = this.value.toUpperCase();
    const rows = document.querySelectorAll('#cropsTable tbody tr');

    rows.forEach(row => {
        const textContent = row.textContent.toUpperCase();
        row.style.display = textContent.includes(filter) ? '' : 'none';
    });
});

// Update Language and Reload Table
document.getElementById('language').addEventListener('change', function () {
    lang = this.value;
    urlParams.set('lang', lang);
    window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);
    applyTranslations(lang);
    fetchData();
});

// Initial Page Load
document.addEventListener('DOMContentLoaded', function () {
    applyTranslations(lang);
    fetchData();
});

if (tableBody.innerHTML === '') {
    tableBody.innerHTML = '<tr class="no-results"><td colspan="4">Keine Ergebnisse gefunden</td></tr>';
}
