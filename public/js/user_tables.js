function GetCellValues(table) {
    let idCol = 0;

    for (let c = 0; c < table.rows[0].length; c++) {
        if (table.rows[0].cells[c].innerHTML == "Account Id") {
            idCol = c;
            break;
        }
    }

    for (let r = 1; r < table.rows.length; r++) {
        let row = table.rows[r];
        let id = row.cells[idCol].innerHTML;
        row.addEventListener('click', () => {
            window.location.href = '/users/' + id;
        });
    }
}

let tables = document.getElementsByTagName("table");
for(let i = 0; i < tables.length; i++) {
    GetCellValues(tables[i]);
}
