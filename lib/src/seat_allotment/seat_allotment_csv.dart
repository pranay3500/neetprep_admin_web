/// Parsed row from NEET-style seat allotment CSV exports.
class SeatAllotmentRow {
  const SeatAllotmentRow({
    required this.serialNo,
    required this.rank,
    required this.allottedQuota,
    required this.instituteName,
    required this.instituteAddressRaw,
    required this.course,
    required this.allottedCategory,
    required this.candidateCategory,
    required this.remarks,
  });

  final int serialNo;
  final int rank;
  final String allottedQuota;
  final String instituteName;
  final String instituteAddressRaw;
  final String course;
  final String allottedCategory;
  final String candidateCategory;
  final String remarks;

  Map<String, dynamic> toFirestoreMap() {
    return {
      'serialNo': serialNo,
      'rank': rank,
      'allottedQuota': allottedQuota,
      'instituteName': instituteName,
      'instituteAddressRaw': instituteAddressRaw,
      'course': course,
      'allottedCategory': allottedCategory,
      'candidateCategory': candidateCategory,
      'remarks': remarks,
    };
  }
}

class SeatAllotmentCsvParseResult {
  const SeatAllotmentCsvParseResult({
    required this.rows,
    required this.errors,
    required this.headerLine,
  });

  final List<SeatAllotmentRow> rows;
  final List<String> errors;
  final String headerLine;

  bool get ok => errors.isEmpty && rows.isNotEmpty;
}

/// RFC 4180-style CSV parse (quoted fields, commas inside quotes).
List<List<String>> parseCsvRecords(String raw) {
  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final records = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
      continue;
    }
    if (ch == ',') {
      row.add(field.toString().trim());
      field.clear();
      continue;
    }
    if (ch == '\n') {
      row.add(field.toString().trim());
      field.clear();
      if (row.any((c) => c.isNotEmpty)) records.add(row);
      row = <String>[];
      continue;
    }
    field.write(ch);
  }
  row.add(field.toString().trim());
  if (row.any((c) => c.isNotEmpty)) records.add(row);
  return records;
}

String _normHeader(String h) =>
    h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

int? _asInt(String v) {
  final t = v.trim();
  if (t.isEmpty) return null;
  return int.tryParse(t.replaceAll(RegExp(r'[^0-9]'), ''));
}

/// Split `Allotted Institute` into short name + remainder address.
({String name, String address}) splitInstituteField(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return (name: '', address: '');
  final firstComma = trimmed.indexOf(',');
  if (firstComma <= 0) return (name: trimmed, address: '');
  return (
    name: trimmed.substring(0, firstComma).trim(),
    address: trimmed.substring(firstComma + 1).trim(),
  );
}

SeatAllotmentCsvParseResult parseSeatAllotmentCsv(String raw) {
  final records = parseCsvRecords(raw);
  if (records.isEmpty) {
    return const SeatAllotmentCsvParseResult(
      rows: [],
      errors: ['CSV is empty.'],
      headerLine: '',
    );
  }

  final header = records.first;
  final headerLine = header.join(', ');
  final col = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    col[_normHeader(header[i])] = i;
  }

  int? idx(List<String> keys) {
    for (final k in keys) {
      final i = col[k];
      if (i != null) return i;
    }
    return null;
  }

  final iSno = idx(['sno', 'serialno', 'srno', 'slno']);
  final iRank = idx(['rank', 'air', 'allindiarank']);
  final iQuota = idx(['allottedquota', 'quota']);
  final iInst = idx(['allottedinstitute', 'institute', 'college']);
  final iCourse = idx(['course']);
  final iAllotCat = idx(['allottedcategory', 'seatcategory']);
  final iCandCat = idx(['candidatecategory', 'category']);
  final iRemarks = idx(['remarks', 'remark', 'status']);

  final errors = <String>[];
  if (iRank == null) {
    errors.add('Missing required column: Rank');
  }
  if (iInst == null) {
    errors.add('Missing required column: Allotted Institute');
  }
  if (errors.isNotEmpty) {
    return SeatAllotmentCsvParseResult(
      rows: const [],
      errors: errors,
      headerLine: headerLine,
    );
  }

  String cell(List<String> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  final rows = <SeatAllotmentRow>[];
  for (var r = 1; r < records.length; r++) {
    final line = records[r];
    if (line.every((c) => c.trim().isEmpty)) continue;

    final rank = _asInt(cell(line, iRank));
    if (rank == null || rank <= 0) {
      errors.add('Row ${r + 1}: invalid Rank "${cell(line, iRank)}".');
      continue;
    }

    final instituteRaw = cell(line, iInst);
    if (instituteRaw.isEmpty) {
      errors.add('Row ${r + 1}: empty Allotted Institute.');
      continue;
    }

    final split = splitInstituteField(instituteRaw);
    final serial = _asInt(cell(line, iSno)) ?? (rows.length + 1);

    rows.add(
      SeatAllotmentRow(
        serialNo: serial,
        rank: rank,
        allottedQuota: cell(line, iQuota),
        instituteName: split.name,
        instituteAddressRaw: split.address.isEmpty ? instituteRaw : split.address,
        course: cell(line, iCourse),
        allottedCategory: cell(line, iAllotCat),
        candidateCategory: cell(line, iCandCat),
        remarks: cell(line, iRemarks),
      ),
    );
  }

  if (rows.isEmpty && errors.isEmpty) {
    errors.add('No data rows found below the header.');
  }

  return SeatAllotmentCsvParseResult(
    rows: rows,
    errors: errors,
    headerLine: headerLine,
  );
}

Map<String, List<String>> buildFilterOptions(List<SeatAllotmentRow> rows) {
  final quotas = <String>{};
  final courses = <String>{};
  final allottedCats = <String>{};
  final candidateCats = <String>{};
  for (final row in rows) {
    if (row.allottedQuota.isNotEmpty) quotas.add(row.allottedQuota);
    if (row.course.isNotEmpty) courses.add(row.course);
    if (row.allottedCategory.isNotEmpty) allottedCats.add(row.allottedCategory);
    if (row.candidateCategory.isNotEmpty) candidateCats.add(row.candidateCategory);
  }
  final sort = (Set<String> s) => s.toList()..sort();
  return {
    'quotas': sort(quotas),
    'courses': sort(courses),
    'allottedCategories': sort(allottedCats),
    'candidateCategories': sort(candidateCats),
  };
}
