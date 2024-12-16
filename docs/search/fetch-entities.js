let timeout;

function getSelectedLanguage() {
  const radios = document.querySelectorAll('input[name="language"]');
  for (const radio of radios) {
    if (radio.checked) {
      return radio.value;
    }
  }
  return "de";
}

function setSelectedLanguage(lang) {
  const radios = document.querySelectorAll('input[name="language"]');
  let found = false;
  for (const radio of radios) {
    if (radio.value === lang) {
      radio.checked = true;
      found = true;
      break;
    }
  }
  // If no matching language was found, default to 'de'
  if (!found) {
    document.querySelector('input[name="language"][value="de"]').checked = true;
  }
}

async function fetchEntities(query) {
  const language = getSelectedLanguage();
  const sparqlQuery = `
    PREFIX schema: <http://schema.org/>  
    SELECT DISTINCT ?label
    WHERE {
      ?entity schema:name ?label .
      FILTER(LANG(?label) = "${language}") .
      FILTER(REGEX(?label, "${query}", "i")).
    }
    LIMIT 3
  `;
  const endpointUrl = "https://lindas.admin.ch/query";
  const fullUrl = `${endpointUrl}?query=${encodeURIComponent(sparqlQuery)}&format=json`;
  
  try {
    const response = await fetch(fullUrl, {
      headers: { Accept: "application/sparql-results+json" },
    });
    if (!response.ok) {
      console.error("SPARQL request failed:", response.statusText);
      return [];
    }
    const data = await response.json();
    return data.results.bindings.map(item => ({
      label: item.label.value
    }));
  } catch (error) {
    console.error("Error fetching SPARQL data:", error);
    return [];
  }
}

async function fetchFullEntities(query) {
  const language = getSelectedLanguage();
  
  // Split the query by whitespace to get individual terms
  const terms = query.split(/\s+/).filter(t => t.length > 0);

  // Build the FILTER conditions
  const filterConditions = terms.map(term => `REGEX(?label, "${term}", "i")`).join(" && ");

  const sparqlQuery = `
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    PREFIX schema: <http://schema.org/>
    SELECT DISTINCT ?entity ?label ?types
    WHERE {
        ?entity schema:name ?label .
        FILTER(LANG(?label) = "${language}") .
        FILTER(${filterConditions})
        OPTIONAL {
            SELECT DISTINCT ?entity (GROUP_CONCAT(?typeName; SEPARATOR=", ") AS ?types)
            WHERE {
                ?entity a ?type .
                ?type rdfs:label ?typeName .
            }
            GROUP BY ?entity
        }
    }
  `;

  const endpointUrl = "https://lindas.admin.ch/query";
  const fullUrl = `${endpointUrl}?query=${encodeURIComponent(sparqlQuery)}&format=json`;

  try {
    const response = await fetch(fullUrl, {
      headers: { Accept: "application/sparql-results+json" },
    });
    if (!response.ok) {
      console.error("SPARQL request failed:", response.statusText);
      return [];
    }
    const data = await response.json();
    return data.results.bindings.map(item => ({
      id: item.entity.value,
      label: item.label.value,
      types: item.types ? item.types.value : "No types available"
    }));
  } catch (error) {
    console.error("Error fetching SPARQL data:", error);
    return [];
  }
}

function debounce(func, delay) {
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), delay);
  };
}

function renderSuggestions(suggestions, container) {
  container.innerHTML = ""; // Clear previous suggestions

  if (suggestions.length === 0) {
    // Nothing shown if no suggestions
    return;
  }

  suggestions.forEach(suggestion => {
    const suggestionElement = document.createElement("div");
    suggestionElement.className = "suggestion";
    suggestionElement.innerHTML = `
      <strong>${suggestion.label}</strong>
    `;
    
    // On click, set the search input value and trigger search
    suggestionElement.addEventListener("click", async () => {
      const searchInput = document.getElementById("search");
      searchInput.value = suggestion.label;
      
      // Now we mimic pressing Enter or directly invoke the search logic
      await runFullSearch(suggestion.label);
    });
    
    container.appendChild(suggestionElement);
  });
}

function renderTable(results) {
  const tableContainer = document.getElementById("resultsTable");
  tableContainer.innerHTML = ""; // Clear previous table or loading message

  if (results.length === 0) {
    tableContainer.textContent = "No results found.";
    return;
  }

  const table = document.createElement("table");
  table.className = "entity-table";

  const thead = document.createElement("thead");
  const headerRow = document.createElement("tr");

  const nameIriHeader = document.createElement("th");
  nameIriHeader.textContent = "Entity (name and IRI)";
  nameIriHeader.classList.add("name-iri-column");
  headerRow.appendChild(nameIriHeader);

  const typesHeader = document.createElement("th");
  typesHeader.textContent = "RDF types";
  typesHeader.classList.add("types-column");
  headerRow.appendChild(typesHeader);

  thead.appendChild(headerRow);
  table.appendChild(thead);

  const tbody = document.createElement("tbody");
  results.forEach(item => {
    const row = document.createElement("tr");

    const nameIriTd = document.createElement("td");
    nameIriTd.innerHTML = `
      <strong>${item.label}</strong><br>
      <small><a href="${item.id}" target="_blank">${item.id}</a></small>
    `;
    nameIriTd.classList.add("name-iri-column");
    row.appendChild(nameIriTd);

    const typesTd = document.createElement("td");
    typesTd.textContent = item.types;
    typesTd.classList.add("types-column");
    row.appendChild(typesTd);

    tbody.appendChild(row);
  });
  table.appendChild(tbody);

  tableContainer.appendChild(table);
}

function displayStats(numResults, elapsedSeconds) {
  const resultsInfo = document.getElementById("resultsInfo");
  resultsInfo.textContent = `${numResults} distinct entities found on LINDAS in ${elapsedSeconds.toFixed(2)} seconds.`;
}

async function handleInput(event) {
  const query = event.target.value.trim();
  const suggestionsContainer = document.getElementById("suggestions");

  if (query.length < 2) {
    suggestionsContainer.innerHTML = ""; // Clear suggestions if query is too short
    return;
  }

  const suggestions = await fetchEntities(query);
  renderSuggestions(suggestions, suggestionsContainer);
}

// Extract the logic from handleEnterKey to a reusable function
async function runFullSearch(query) {
  if (query.length < 2) {
    return;
  }

  // Update URL
  const newUrl = new URL(window.location.href);
  newUrl.searchParams.set('query', query);
  newUrl.searchParams.set('lang', getSelectedLanguage());
  window.history.pushState({}, '', newUrl);

  // Clear suggestions
  const suggestionsContainer = document.getElementById("suggestions");
  suggestionsContainer.innerHTML = "";

  // Clear old stats
  const resultsInfo = document.getElementById("resultsInfo");
  resultsInfo.textContent = "";

  const tableContainer = document.getElementById("resultsTable");
  tableContainer.innerHTML = '<img src="loading.gif" alt="Loading..." style="display:block; margin:20px auto; width:32px; height:32px;" />';

  const startTime = performance.now();
  const results = await fetchFullEntities(query);
  const endTime = performance.now();
  const elapsedSeconds = (endTime - startTime) / 1000;

  renderTable(results);
  if (results.length > 0) {
    displayStats(results.length, elapsedSeconds);
  }
}

async function handleEnterKey(event) {
  if (event.key === "Enter") {
    const query = event.target.value.trim();
    await runFullSearch(query);
  }
}

const debouncedHandleInput = debounce(handleInput, 50);

document.addEventListener("DOMContentLoaded", () => {
  const searchInput = document.getElementById("search");
  const params = new URLSearchParams(window.location.search);

  const storedQuery = params.get('query');
  const storedLang = params.get('lang');

  // Restore language if available
  if (storedLang) {
    setSelectedLanguage(storedLang);
  } else {
    // If not specified, default is 'de' as per getSelectedLanguage() fallback
    // After selecting default, update URL as well
    setSelectedLanguage('de');
  }

  // Ensure URL always has the lang param
  const currentUrl = new URL(window.location.href);
  if (!currentUrl.searchParams.get('lang')) {
    currentUrl.searchParams.set('lang', getSelectedLanguage());
    window.history.replaceState({}, '', currentUrl);
  }

  // If a query is available, run it immediately
  if (storedQuery && storedQuery.trim().length >= 2) {
    (async () => {
      const tableContainer = document.getElementById("resultsTable");
      tableContainer.innerHTML = '<img src="loading.gif" alt="Loading..." style="display:block; margin:20px auto; width:32px; height:32px;" />';
      const startTime = performance.now();
      const results = await fetchFullEntities(storedQuery);
      const endTime = performance.now();
      const elapsedSeconds = (endTime - startTime) / 1000;
      renderTable(results);
      if (results.length > 0) {
        displayStats(results.length, elapsedSeconds);
      }
      searchInput.value = storedQuery;
    })();
  }

  searchInput.addEventListener("input", debouncedHandleInput);
  searchInput.addEventListener("keydown", handleEnterKey);

  // Add event listener to language radios to update lang in URL immediately
  const languageRadios = document.querySelectorAll('input[name="language"]');
  languageRadios.forEach(radio => {
    radio.addEventListener('change', () => {
      const url = new URL(window.location.href);
      url.searchParams.set('lang', getSelectedLanguage());
      window.history.pushState({}, '', url);
    });
  });
});
