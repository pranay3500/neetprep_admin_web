import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_db.dart';

class EligibilityToolPage extends StatefulWidget {
  const EligibilityToolPage({super.key});

  @override
  State<EligibilityToolPage> createState() => _EligibilityToolPageState();
}

class _EligibilityToolPageState extends State<EligibilityToolPage> {
  final _coll = FirestoreDb.instance.collection('cms_eligibility_rules');

  bool _initialized = false;
  bool _saving = false;
  String? _status;
  String? _error;

  final _thresholdGeneral = TextEditingController(text: '50');
  final _thresholdObc = TextEditingController(text: '40');
  final _thresholdPwd = TextEditingController(text: '45');
  final _logicJson = TextEditingController();

  final Map<String, TextEditingController> _plainCtrls = {};
  final Map<String, TextEditingController> _legalCtrls = {};
  static const List<String> _defaultRuleIds = [
    'AGE_FAIL',
    'NO_PHY',
    'NO_CHEM',
    'NO_BIO',
    'NO_ENG',
    'PCB_LOW',
    'IB_PARTIAL',
    'BOARD_AIU',
    'NO_PRACTICAL',
    'NEET_CENTER_WARN',
    'AIU_URGENT',
    'PASSPORT_FLAG',
    'OCI_DIRECT',
    'NO_NRI_STATUS',
    'TOURIST_VISA',
    'CONDITIONAL_NRI',
    'PRIORITY2_SPONSOR',
    'SHORT_ABROAD',
    'DOCS_MISSING',
    'FINANCIAL_RISK',
    'KA_DOCS_FLAG',
    'DEPUTATION_NRI_ELIGIBLE',
    'OCI_GENERAL_MERIT_POOL',
    'COUSIN_SPONSOR',
    'FOREIGN_NATIONAL',
    'NIOS_CHECK',
    'NRI_QUOTA_PCB_WARN',
    'NEET_SCORE_EXPIRY_ATTEMPT',
    'FLAG_MANUAL_REVIEW',
  ];
  static const Map<String, Map<String, String>> _defaultRuleMessages = {
    'AGE_FAIL': {
      'plain': 'Student is below minimum age requirement.',
      'legal': 'Minimum age is 17 years by Dec 31.',
    },
    'NO_PHY': {
      'plain': 'Physics is mandatory.',
      'legal': 'NMC requires Physics in qualifying exam.',
    },
    'NO_CHEM': {
      'plain': 'Chemistry is mandatory.',
      'legal': 'NMC requires Chemistry in qualifying exam.',
    },
    'NO_BIO': {
      'plain': 'Biology/Biotechnology is mandatory.',
      'legal': 'NMC requires Biology/Biotechnology.',
    },
    'NO_ENG': {
      'plain': 'English is mandatory.',
      'legal': 'NTA requires English in qualifying exam.',
    },
    'PCB_LOW': {
      'plain': 'PCB percentage is below required threshold.',
      'legal': 'Threshold depends on category.',
    },
    'IB_PARTIAL': {
      'plain': 'IB Partial is not valid for NEET equivalence.',
      'legal': 'Only full IB Diploma accepted.',
    },
    'BOARD_AIU': {
      'plain': 'AIU equivalence required.',
      'legal': 'Foreign boards require AIU at counseling.',
    },
    'NO_PRACTICAL': {
      'plain': 'Lab/practical component missing or unclear.',
      'legal': 'Science practicals required.',
    },
    'NEET_CENTER_WARN': {
      'plain': 'Selected country has no NEET center.',
      'legal': 'Travel to listed NTA center country is required.',
    },
    'AIU_URGENT': {
      'plain': 'AIU process should start immediately.',
      'legal': 'AIU certificate needed in counseling.',
    },
    'PASSPORT_FLAG': {
      'plain': 'Valid passport required.',
      'legal': 'Passport required for NEET/NRI documentation.',
    },
    'OCI_DIRECT': {
      'plain': 'OCI override applied: direct NRI quota eligibility.',
      'legal': 'OCI check runs first.',
    },
    'NO_NRI_STATUS': {
      'plain':
          'No qualifying NRI, OCI, or PIO connection has been found in your family. Your child is not eligible for the NRI quota.',
      'legal':
          'NRI quota requires either: (1) student or parent is NRI (Priority 1), (2) grandparent, sibling, uncle, or aunt is NRI (Priority 2), (3) student holds OCI/PIO, or (4) sponsor relationship classified as conditional with valid documentation. None of these conditions are met.',
    },
    'TOURIST_VISA': {
      'plain': 'Tourist visa is not valid for NRI quota.',
      'legal': 'Tourist/visit visas do not establish NRI status.',
    },
    'CONDITIONAL_NRI': {
      'plain':
          'Your sponsor\'s visa type is accepted by some colleges and states but not all — verification is needed at each institution.',
      'legal':
          'Conditional visa classes (F1, H4, dependent visas, etc.) are accepted at institutional discretion. Note: Indian-origin foreign nationals without OCI are now routed separately via FOREIGN_NATIONAL flag, not this flag.',
    },
    'PRIORITY2_SPONSOR': {
      'plain':
          'Your sponsor qualifies under Priority 2. NRI seats are filled in order — Priority 1 (parent or student) first, then Priority 2. Your child\'s application is valid but will only be considered after all Priority 1 candidates are accommodated.',
      'legal':
          'MCC allocates NRI quota seats sequentially under Anshul Tomar guidelines (SC W.P. 13393/2007). Priority 2 sponsors include grandparents, real siblings, uncles, and aunts. Seat availability for Priority 2 depends on residual seats after Priority 1 allotment.',
    },
    'SHORT_ABROAD': {
      'plain':
          'Your sponsor has not been abroad long enough to firmly establish NRI status — the minimum is 182 days in a financial year.',
      'legal':
          'NRI status under Income Tax Act Section 6 and adopted by NMC/MCC requires the sponsor to have been outside India for more than 182 days in the relevant financial year. MEA\'s July 2025 revised NRI certificate guidelines apply. Short stay triggers additional scrutiny and may require multi-year residence proof.',
    },
    'DOCS_MISSING': {
      'plain':
          'Sponsor documents are incomplete. Required documents depend on your sponsor\'s priority level — Priority 1 (parent) needs fewer proofs than Priority 2 (grandparent, sibling, uncle, aunt).',
      'legal':
          'MCC 2025 mandatory document list requires: NRI certificate from Indian Embassy/Consulate, family-tree certificate from competent Revenue Authority, notarised sponsorship affidavit with NRE bank account passbook, sponsor\'s passport and visa copies, and relationship certificate. Priority 2 sponsors may require additional relationship chain documentation (e.g. linking student → parent → uncle/aunt).',
    },
    'FINANCIAL_RISK': {
      'plain': 'Financial capability risk flagged.',
      'legal': 'NRI seats often need financial evidence.',
    },
    'KA_DOCS_FLAG': {
      'plain': 'Karnataka requires strict embassy/family docs.',
      'legal': 'KEA has stricter document timelines and proof rules.',
    },
    'DEPUTATION_NRI_ELIGIBLE': {
      'plain':
          'NRI quota: child of Government employee on overseas deputation qualifies under NMC/MCC norms.',
      'legal':
          'State/Central Govt employees stationed abroad during deputation and their dependents are recognised as qualifying NRI cases for quota — verify embassy and employer letters at counselling.',
    },
    'OCI_GENERAL_MERIT_POOL': {
      'plain':
          'As an OCI holder your child is confirmed eligible for the NRI quota. They may also be able to compete in the general merit pool — which can be more competitive but offers better colleges if the NEET score is strong.',
      'legal':
          'MCC 2025 counselling brochure and state bulletins permit OCI holders to participate in both NRI quota and open/general merit pool simultaneously in many states. The ociAlsoEligibleForGeneralMerit flag in v2 config ensures this advisory fires on the OCI path and is not suppressed by the OCI short-circuit.',
    },
    'COUSIN_SPONSOR': {
      'plain':
          'Your first cousin (child of your uncle or aunt) is a valid NRI sponsor under Supreme Court guidelines, but falls under Priority 2. Seat allotment happens after Priority 1 candidates. Documentation requirements are strict and vary by state.',
      'legal':
          'First cousins (son/daughter of paternal or maternal uncle/aunt) are recognised as Priority 2 sponsors under Anshul Tomar guidelines. They are listed in sponsorRelationships.conditional in v2 config. Karnataka requires family-tree certificate from Revenue Authority; other states may accept notarised affidavit. Deemed universities follow MCC/DGHS norms.',
    },
    'FOREIGN_NATIONAL': {
      'plain':
          'Your child appears to be a foreign national of Indian origin without an OCI card. This requires verification under the foreign national quota — not the NRI quota.',
      'legal':
          'Indian-origin foreign citizens without OCI status are not eligible for NRI quota seats. They may apply under the foreign national category subject to NMC/state rules and bilateral agreements. OCI card acquisition should be considered.',
    },
    'NIOS_CHECK': {
      'plain':
          'Your child\'s NIOS qualification needs verification before NEET registration can be confirmed.',
      'legal':
          'NIOS students studying abroad or with non-standard subject combinations may face state-specific restrictions. AIU equivalence or counselling authority confirmation may be required depending on the subject profile and target state.',
    },
    'NRI_QUOTA_PCB_WARN': {
      'plain':
          'PCB meets common NEET registration thresholds but several NRI seats require ≈60% aggregate PCB — verify each institute.',
      'legal':
          'Institution brochures may prescribe higher PCB than statutory minima — keep board marksheets aligned with counselling checks.',
    },
    'NEET_SCORE_EXPIRY_ATTEMPT': {
      'plain':
          'If an older NEET attempt is reused, counselling may reject it — new attempt may be mandatory.',
      'legal':
          'NEET rankings are ordinarily valid for admission in the same academic intake; confirm DGHS/MCC bulletin for validity rules.',
    },
    'FLAG_MANUAL_REVIEW': {
      'plain':
          'Sponsor relationship needs document review with target counselling authority.',
      'legal': 'Non-standard relationships are verified case-by-case at admission.',
    },
  };

  @override
  void dispose() {
    _thresholdGeneral.dispose();
    _thresholdObc.dispose();
    _thresholdPwd.dispose();
    _logicJson.dispose();
    for (final c in _plainCtrls.values) {
      c.dispose();
    }
    for (final c in _legalCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (_initialized) return;
    _initialized = true;
    final logic = <String, dynamic>{};
    for (final d in docs) {
      final data = d.data();
      if (d.id == 'thresholds') {
        _thresholdGeneral.text = (data['general_nri_oci_pio'] ?? 50).toString();
        _thresholdObc.text = (data['obc_sc_st'] ?? 40).toString();
        _thresholdPwd.text = (data['pwd'] ?? 45).toString();
        continue;
      }
      if (d.id == 'logic_config') {
        logic.addAll(data);
        continue;
      }
      _plainCtrls[d.id] = TextEditingController(
        text: (data['plain'] ?? '').toString(),
      );
      _legalCtrls[d.id] = TextEditingController(
        text: (data['legal'] ?? '').toString(),
      );
    }

    if (logic.isEmpty) {
      logic.addAll(const {
        'version': '2.0',
        'lastUpdated': '2026-05-29',
        'thresholds': {
          'general_nri_oci_pio': 50,
          'obc_sc_st': 40,
          'pwd': 45,
          'nri_quota_pcb_advisory': 60,
        },
        'ageRules': {
          'minimumAge': 17,
          'deadlineMonth': 12,
          'deadlineDay': 31,
        },
        'subjectRules': {
          'requiredSubjects': [
            'physics',
            'chemistry',
            'biology_or_biotechnology',
            'english'
          ],
          'biologyAliases': ['biology', 'biotechnology'],
          'requiredSubjectFlags': {
            'physics': 'NO_PHY',
            'chemistry': 'NO_CHEM',
            'biology_or_biotechnology': 'NO_BIO',
            'english': 'NO_ENG'
          },
          'additionalSubjectAllowed': true,
          'additionalSubjectNote':
              'PCM students who added Biology or Biotechnology as an additional subject in Grade 12 are fully eligible for NEET. Biology does not need to be a core stream subject.'
        },
        'boardRules': {
          'requiresBothYearsBoards': [
            'ib_full_diploma',
            'igcse_cambridge',
            'american_ap',
            'american_home',
            'uae_ministry',
            'gcc_ministry',
            'other_intl'
          ],
          'indianBoardsForClass12Only': [
            'cbse',
            'cbse_abroad',
            'icse',
            'indian_state_board',
            'nios'
          ],
          'hardFailBoards': ['ib_partial'],
          'aiuRequiredBoards': [
            'ib_full_diploma',
            'igcse_cambridge',
            'american_ap',
            'american_home',
            'uae_ministry',
            'gcc_ministry',
            'other_intl'
          ],
          'localBoardFlagBoards': ['uae_ministry', 'gcc_ministry'],
          'practicalQuestionBoards': [
            'ib_full_diploma',
            'igcse_cambridge',
            'american_ap',
            'american_home',
            'uae_ministry',
            'gcc_ministry',
            'other_intl'
          ]
        },
        'neetCenterRules': {
          'countriesWithCenters': [
            'india',
            'uae',
            'qatar',
            'kuwait',
            'bahrain',
            'oman',
            'saudi_arabia',
            'singapore',
            'malaysia',
            'nepal',
            'sri_lanka',
            'thailand',
            'nigeria'
          ]
        },
        'nriQuotaRules': {
          'ociShortCircuit': true,
          'ociAlsoEligibleForGeneralMerit': true,
          'govtDeputationEligible': true,
          'softenTouristVisaForForeignIndianParent': true,
          'nriQuotaPcbAdvisoryEnabled': true,
          'hardFailRelations': ['none'],
          'sponsorRelationships': {
            'priority1': [
              {'id': 'self', 'label': 'Student (self)'},
              {'id': 'father', 'label': 'Father'},
              {'id': 'mother', 'label': 'Mother'},
            ],
            'priority2': [
              {'id': 'brother', 'label': 'Brother (real sibling)'},
              {'id': 'sister', 'label': 'Sister (real sibling)'},
              {'id': 'grandfather_paternal', 'label': 'Grandfather (paternal)'},
              {'id': 'grandmother_paternal', 'label': 'Grandmother (paternal)'},
              {'id': 'grandfather_maternal', 'label': 'Grandfather (maternal)'},
              {'id': 'grandmother_maternal', 'label': 'Grandmother (maternal)'},
              {'id': 'uncle_fathers_brother', 'label': 'Uncle (father\'s brother)'},
              {'id': 'aunt_fathers_sister', 'label': 'Aunt (father\'s sister)'},
              {'id': 'uncle_mothers_brother', 'label': 'Uncle (mother\'s brother)'},
              {'id': 'aunt_mothers_sister', 'label': 'Aunt (mother\'s sister)'},
            ],
            'conditional': [
              {'id': 'first_cousin_paternal', 'label': 'First cousin (paternal)'},
              {'id': 'first_cousin_maternal', 'label': 'First cousin (maternal)'},
            ],
            'manualReview': [
              {'id': 'other', 'label': 'Other (manual review)'},
            ],
          },
          'visaRules': {
            'USA': [
              {'id': 'h1b', 'status': 'eligible'},
              {'id': 'l1', 'status': 'eligible'},
              {'id': 'o1', 'status': 'eligible'},
              {'id': 'green_card', 'status': 'eligible'},
              {'id': 'us_citizen_oci', 'status': 'oci'},
              {
                'id': 'us_citizen',
                'status': 'foreign_national',
                'note': 'US citizen without OCI — foreign national quota, not NRI'
              },
              {'id': 'f1', 'status': 'conditional'},
              {'id': 'j1', 'status': 'conditional'},
              {'id': 'h4', 'status': 'conditional'},
              {'id': 'tn', 'status': 'conditional'},
              {'id': 'b1_b2', 'status': 'tourist'}
            ],
            'UAE': [
              {'id': 'uae_employment', 'status': 'eligible'},
              {'id': 'uae_investor', 'status': 'eligible'},
              {'id': 'uae_golden', 'status': 'eligible'},
              {'id': 'uae_freelancer', 'status': 'eligible'},
              {'id': 'uae_retirement', 'status': 'eligible'},
              {'id': 'uae_dependent', 'status': 'conditional'},
              {'id': 'uae_visit', 'status': 'tourist'}
            ],
            'Kuwait': [
              {'id': 'kuwait_work', 'status': 'eligible'},
              {'id': 'kuwait_dependent', 'status': 'conditional'},
              {'id': 'kuwait_visit', 'status': 'tourist'}
            ],
            'Qatar': [
              {'id': 'qatar_qid', 'status': 'eligible'},
              {'id': 'qatar_dependent', 'status': 'conditional'},
              {'id': 'qatar_visit', 'status': 'tourist'}
            ],
            'Oman': [
              {'id': 'oman_employment', 'status': 'eligible'},
              {'id': 'oman_dependent', 'status': 'conditional'},
              {'id': 'oman_visit', 'status': 'tourist'}
            ],
            'Bahrain': [
              {'id': 'bahrain_cpr', 'status': 'eligible'},
              {'id': 'bahrain_dependent', 'status': 'conditional'},
              {'id': 'bahrain_visit', 'status': 'tourist'}
            ],
            'Saudi Arabia': [
              {'id': 'saudi_iqama', 'status': 'eligible'},
              {'id': 'saudi_employment', 'status': 'eligible'},
              {'id': 'saudi_investor', 'status': 'eligible'},
              {'id': 'saudi_dependent', 'status': 'conditional'},
              {'id': 'saudi_visit', 'status': 'tourist'}
            ],
            'Singapore': [
              {'id': 'sg_ep', 'status': 'eligible'},
              {'id': 'sg_spass', 'status': 'eligible'},
              {'id': 'sg_pr', 'status': 'eligible'},
              {'id': 'sg_citizen_oci', 'status': 'oci'},
              {'id': 'sg_dependent', 'status': 'conditional'}
            ],
            'Other': [
              {'id': 'employment', 'status': 'eligible'},
              {'id': 'oci_card', 'status': 'oci'},
              {'id': 'pio_card', 'status': 'eligible'},
              {'id': 'dependent', 'status': 'conditional'},
              {'id': 'tourist', 'status': 'tourist'}
            ]
          },
          'durationRules': {
            'minDaysAbroad': 182,
            'shortAbroadValues': ['less_1', 'travelling']
          }
        },
        'flagTriggerRules': {
          'NIOS_CHECK': {
            'type': 'board',
            'boards': ['nios'],
            'requireAbroad': false
          },
          'FOREIGN_NATIONAL': {
            'type': 'foreignNationalWithoutOci'
          },
          'PRIORITY2_SPONSOR': {
            'type': 'sponsorTier',
            'tier': 'priority2'
          },
          'OCI_GENERAL_MERIT_POOL': {
            'type': 'ociGeneralMeritAdvisory'
          }
        },
        'flagSeverity': {
          'neet': {
            'hardFail': [
              'AGE_FAIL',
              'NO_PHY',
              'NO_CHEM',
              'NO_BIO',
              'NO_ENG',
              'PCB_LOW',
              'IB_PARTIAL'
            ],
            'conditional': [
              'BOARD_AIU',
              'LOCAL_BOARD',
              'NIOS_CHECK',
              'NO_PRACTICAL',
              'FOREIGN_NATIONAL',
              'PASSPORT_FLAG',
              'AIU_URGENT'
            ],
            'advisory': ['NEET_CENTER_WARN', 'NEET_SCORE_EXPIRY_ATTEMPT']
          },
          'nri': {
            'hardFail': ['NO_NRI_STATUS', 'TOURIST_VISA', 'NOT_BLOOD'],
            'conditional': [
              'CONDITIONAL_NRI',
              'PRIORITY2_SPONSOR',
              'SHORT_ABROAD',
              'DOCS_MISSING',
              'FINANCIAL_RISK',
              'CHANDIGARH_RULE',
              'FLAG_MANUAL_REVIEW',
              'COUSIN_SPONSOR'
            ],
            'advisory': [
              'KA_DOCS_FLAG',
              'NRI_QUOTA_PCB_WARN',
              'OCI_GENERAL_MERIT_POOL',
              'DEPUTATION_NRI_ELIGIBLE',
              'NEET_SCORE_EXPIRY_ATTEMPT'
            ]
          }
        }
      });
    }
    for (final id in _defaultRuleIds) {
      final defaults = _defaultRuleMessages[id] ?? const <String, String>{};
      _plainCtrls.putIfAbsent(
        id,
        () => TextEditingController(text: defaults['plain'] ?? ''),
      );
      _legalCtrls.putIfAbsent(
        id,
        () => TextEditingController(text: defaults['legal'] ?? ''),
      );
      if (_plainCtrls[id]!.text.trim().isEmpty && (defaults['plain'] ?? '').isNotEmpty) {
        _plainCtrls[id]!.text = defaults['plain']!;
      }
      if (_legalCtrls[id]!.text.trim().isEmpty && (defaults['legal'] ?? '').isNotEmpty) {
        _legalCtrls[id]!.text = defaults['legal']!;
      }
    }
    _logicJson.text = const JsonEncoder.withIndent('  ').convert(logic);
  }

  Future<void> _save() async {
    Map<String, dynamic> logic;
    try {
      final decoded = jsonDecode(_logicJson.text);
      if (decoded is! Map) throw const FormatException('JSON must be object');
      logic = Map<String, dynamic>.from(decoded);
    } catch (e) {
      setState(() {
        _error = 'Logic JSON is invalid: $e';
        _status = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _status = null;
    });

    try {
      final batch = FirestoreDb.instance.batch();
      batch.set(_coll.doc('thresholds'), {
        'general_nri_oci_pio':
            double.tryParse(_thresholdGeneral.text.trim()) ?? 50,
        'obc_sc_st': double.tryParse(_thresholdObc.text.trim()) ?? 40,
        'pwd': double.tryParse(_thresholdPwd.text.trim()) ?? 45,
      }, SetOptions(merge: true));
      batch.set(_coll.doc('logic_config'), logic, SetOptions(merge: true));

      for (final id in _plainCtrls.keys) {
        batch.set(_coll.doc(id), {
          'plain': _plainCtrls[id]!.text.trim(),
          'legal': _legalCtrls[id]!.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      setState(() => _status = 'Eligibility tool settings saved.');
    } catch (e) {
      setState(() => _error = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _coll.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_initialized) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? const [];
        _hydrate(docs);
        final ruleIds = _plainCtrls.keys.toList()..sort();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Eligibility Tool',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage checker logic and all “Read Legal Detail” text from admin. Changes sync to app via Firestore.',
            ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _status!,
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Thresholds',
              child: Column(
                children: [
                  _field(_thresholdGeneral, 'General / NRI / OCI / PIO PCB %'),
                  const SizedBox(height: 10),
                  _field(_thresholdObc, 'OBC / SC / ST PCB %'),
                  const SizedBox(height: 10),
                  _field(_thresholdPwd, 'PwD PCB %'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Logic Configuration (JSON)',
              subtitle:
                  'This defines rule behavior in app (board grouping, practical question visibility, special visa handling).',
              child: TextFormField(
                controller: _logicJson,
                minLines: 12,
                maxLines: 20,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{\n  "requiresBothYearsBoards": [...]\n}',
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Rule Messages',
              subtitle:
                  'Edit the plain text and “Read Legal Detail” content shown in the app result cards.',
              child: ruleIds.isEmpty
                  ? const Text(
                      'No rules found yet. Add rules and save once to initialize.',
                    )
                  : Column(
                      children: [
                        for (final id in ruleIds) ...[
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 12),
                            title: Text(
                              id,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4527A0),
                              ),
                            ),
                            subtitle: Text(
                              _plainCtrls[id]!.text.trim().isEmpty
                                  ? 'Tap to add message'
                                  : _plainCtrls[id]!.text.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            children: [
                              _field(_plainCtrls[id]!, 'Plain message'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _legalCtrls[id],
                                minLines: 3,
                                maxLines: 8,
                                decoration: const InputDecoration(
                                  labelText: 'Read Legal Detail content',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 1),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 36),
          ],
        );
      },
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}

