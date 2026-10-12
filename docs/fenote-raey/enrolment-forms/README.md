# Fenote Raey Academy — enrolment forms

Paper forms that match **MayaBela** registration screens. Families and staff fill the white sections. After the record is saved, the registrar copies the IDs the software created into the yellow **Office use only** box.

| Form | Software screen | File |
|---|---|---|
| Student | Admin → Add Student | [Fenote_Raey_Student_Enrolment_Form.pdf](Fenote_Raey_Student_Enrolment_Form.pdf) |
| Teacher | Admin → Add Teacher | [Fenote_Raey_Teacher_Enrolment_Form.pdf](Fenote_Raey_Teacher_Enrolment_Form.pdf) |
| Administrative staff | Admin → Add Administration Staff | [Fenote_Raey_Administrative_Staff_Enrolment_Form.pdf](Fenote_Raey_Administrative_Staff_Enrolment_Form.pdf) |
| All three + how-to | Print this pack | [Fenote_Raey_Enrolment_Forms_Pack.pdf](Fenote_Raey_Enrolment_Forms_Pack.pdf) |
| Excel (forms + registers) | Fill in Excel (full or partial), then **Import Excel** in MayaBela | [Fenote_Raey_Enrolment_Forms.xlsx](Fenote_Raey_Enrolment_Forms.xlsx) |

MayaBela reads this workbook on **Students**, **Classroom Teachers**, **Administration Staff**, and **Go-live → Import**. Empty rows are skipped. Missing optional fields stay blank. Gold office ID columns are ignored — the software issues `STU-####` / `TCH-####` / role-prefix IDs after save. Students need a full name and date of birth; teachers and staff need name, a real email, and a login phone.

Regenerate after field changes:

```bash
python3 tools/generate_fenote_enrolment_forms.py
python3 tools/generate_fenote_enrolment_excel.py
```

Do **not** write Student ID / Teacher ID / Staff ID before saving in MayaBela. The software issues `STU-####`, `TCH-####`, or a role prefix such as `QA-####` / `HR-####` / `REG-####`.
