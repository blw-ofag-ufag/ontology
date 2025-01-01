// Embedded translations (instead of fetching from a JSON file)
const translations = {
    "de": {
        "title": "Kulturentabelle",
        "subtitle": "<p>Hier findest du die Liste der landwirtschaftlichen Kulturen des Bundesamtes für Landwirtschaft BLW. Diese Liste ist <i>fast</i> komplett. Das tatsächliche File mit den Daten liegt auf <a href='https://github.com/blw-ofag-ufag/ontology/blob/main/mapping-tables/crops.json'>GitHub</a>.</p><p>Der Kulturentyp ist noch in der Entwicklung und besteht im Moment aus Ackerbau (🌾), Gemüsebau (🥬), Obst (🍎), Beerenbau (🫐), Weinbau (🍇), Medizinalpflanzen (🌿), Ornamentalkulturen (🌺), Forstwirtschaft (🌲), und Nicht-Kulturen (🏭).</p>",
        "search": "Durchsuche nach Name, Kommentar etc.",
        "columns": ["ID", "Name", "Kommentare", "Typ"]
    },
    "fr": {
        "title": "Tableau des Cultures",
        "subtitle": "<p>Voici la liste des cultures agricoles de l'Office fédéral de l'agriculture OFAG. Cette liste est <i>presque</i> complète. Le fichier réel contenant les données est disponible sur <a href='https://github.com/blw-ofag-ufag/ontology/blob/main/mapping-tables/crops.json'>GitHub</a>.</p><p>Le type de culture est encore en développement et comprend actuellement les grandes cultures (🌾), les légumes (🥬), les fruits (🍎), les baies (🫐), la viticulture (🍇), les plantes médicinales (🌿), les cultures ornementales (🌺), la sylviculture (🌲) et les non-cultures (🏭).</p>",
        "search": "Rechercher par nom, commentaire, etc.",
        "columns": ["ID", "Nom", "Commentaires", "Type"]
    },
    "it": {
        "title": "Tabella delle Colture",
        "subtitle": "<p>Qui trovi l'elenco delle colture agricole dell'Ufficio federale dell'agricoltura UFAG. Questo elenco è <i>quasi</i> completo. Il file reale con i dati è disponibile su <a href='https://github.com/blw-ofag-ufag/ontology/blob/main/mapping-tables/crops.json'>GitHub</a>.</p><p>Il tipo di coltura è ancora in fase di sviluppo e attualmente comprende seminativi (🌾), ortaggi (🥬), frutta (🍎), bacche (🫐), viticoltura (🍇), piante medicinali (🌿), colture ornamentali (🌺), selvicoltura (🌲) e non colture (🏭).</p>",
        "search": "Cerca per nome, commento, ecc.",
        "columns": ["ID", "Nome", "Commenti", "Tipo"]
    },
    "en": {
        "title": "Crops Table",
        "subtitle": "<p>Here you can find the list of agricultural crops from the Federal Office for Agriculture FOAG. This list is <i>almost</i> complete. The actual file with the data is available on <a href='https://github.com/blw-ofag-ufag/ontology/blob/main/mapping-tables/crops.json'>GitHub</a>.</p><p>The crop type is still under development and currently includes arable crops (🌾), vegetables (🥬), fruits (🍎), berries (🫐), viticulture (🍇), medicinal plants (🌿), ornamental crops (🌺), forestry (🌲), and non-crops (🏭).</p>",
        "search": "Search by name, comment, etc.",
        "columns": ["ID", "Name", "Comments", "Type"]
    }
};

// Global Declarations
const tableBody = document.querySelector('#cropsTable tbody');
const dataUrl = 'https://raw.githubusercontent.com/blw-ofag-ufag/ontology/main/mapping-tables/crops.json';
const urlParams = new URLSearchParams(window.location.search);
let lang = urlParams.get('lang') || 'de';

// Apply Translations to Static Page Elements
function applyTranslations(lang) {
    const t = translations[lang] || translations['de'];

    document.title = t.title;
    document.getElementById('titleHeading').textContent = t.title;
    document.getElementById('searchInput').placeholder = t.search;
    document.getElementById('subtitle').innerHTML = t.subtitle;

    const headers = t.columns;
    document.getElementById('col1').textContent = headers[0];
    document.getElementById('col2').textContent = headers[1];
    document.getElementById('col3').textContent = headers[2];
    document.getElementById('col4').textContent = headers[3];
}

// Fetch and Populate Table
function fetchData() {
    fetch(dataUrl)
        .then(response => response.json())
        .then(data => {
            tableBody.innerHTML = '';

            // Populate table
            data.forEach(item => {
                const row = document.createElement('tr');

                row.innerHTML = `
                    <td>${item['srppp-id'] || ''}</td>
                    <td>${item.label?.[lang]?.[0] || ''}</td>
                    <td>${item.comment?.[lang] || ''}</td>
                    <td>${getTypeEmoji(item.type)}</td>
                `;

                tableBody.appendChild(row);
            });

            applyURLParams();  // Apply search/sort after populating
        })
        .catch(error => console.error('Fehler beim Laden der Daten:', error));
}

// Map Crop Types to Emojis
function getTypeEmoji(type) {
    const typeMapping = {
        arable: '🌾',
        medical: '🌿',
        vegetable: '🥬',
        fruit: '🍎',
        berry: '🫐',
        viticulture: '🍇',
        ornamental: '🌺',
        forestry: '🌲',
        noncrop: '🏭'
    };
    return typeMapping[type] || '';
}

// Apply Sorting and Search from URL
function applyURLParams() {
    const searchTerm = urlParams.get('search');
    const sortColumn = urlParams.get('sort');
    const sortDirection = urlParams.get('dir');

    if (searchTerm) {
        document.getElementById('searchInput').value = searchTerm;
        filterTable(searchTerm);
    }

    if (sortColumn !== null && sortDirection !== null) {
        sortTable(parseInt(sortColumn), true);
    }
}

// Sort Table by Column
function sortTable(columnIndex, preserveDirection = false) {
    const table = document.getElementById('cropsTable');
    const rows = Array.from(table.rows).slice(1);
    let currentDirection = urlParams.get('dir') || 'asc';

    if (!preserveDirection) {
        currentDirection = currentDirection === 'asc' ? 'desc' : 'asc';
    }

    rows.sort((a, b) =>
        a.cells[columnIndex].textContent.localeCompare(b.cells[columnIndex].textContent)
        * (currentDirection === 'asc' ? 1 : -1)
    );

    tableBody.innerHTML = '';
    rows.forEach(row => tableBody.appendChild(row));

    urlParams.set('sort', columnIndex);
    urlParams.set('dir', currentDirection);
    window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);
}

// Filter/Search Table and Update URL
function filterTable(searchTerm) {
    const rows = document.querySelectorAll('#cropsTable tbody tr');
    rows.forEach(row => {
        row.style.display = row.textContent.toUpperCase().includes(searchTerm.toUpperCase()) ? '' : 'none';
    });

    // Update URL with search parameter
    urlParams.set('search', searchTerm);
    window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);
}

// INITIALIZE ON PAGE LOAD
document.addEventListener('DOMContentLoaded', function () {
    applyTranslations(lang);
    document.getElementById('language').value = lang;
    fetchData();
});

// Language Selection
document.getElementById('language').addEventListener('change', function () {
    lang = this.value;
    urlParams.set('lang', lang);
    window.history.replaceState({}, '', `${window.location.pathname}?${urlParams.toString()}`);
    applyTranslations(lang);
    fetchData();
});

// Attach URL Update to Search Event
document.getElementById('searchInput').addEventListener('input', function() {
    const searchTerm = this.value;
    filterTable(searchTerm);  // Filter and update URL
});