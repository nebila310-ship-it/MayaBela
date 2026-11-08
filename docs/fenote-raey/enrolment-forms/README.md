# Fenote Raey Academy — enrolment forms

Paper forms that match **MayaBela** registration screens. Families and staff fill the white sections. After the record is saved, the registrar copies the IDs the software created into the yellow **Office use only** box.

| Form | Software screen | File |
|---|---|---|
| Student | Admin → Add Student | [Fenote_Raey_Student_Enrolment_Form.pdf](Fenote_Raey_Student_Enrolment_Form.pdf) |
| Teacher | Admin → Add Teacher | [Fenote_Raey_Teacher_Enrolment_Form.pdf](Fenote_Raey_Teacher_Enrolment_Form.pdf) |
| Administrative staff | Admin → Add Administration Staff | [Fenote_Raey_Administrative_Staff_Enrolment_Form.pdf](Fenote_Raey_Administrative_Staff_Enrolment_Form.pdf) |
| All three + how-to | Print this pack | [Fenote_Raey_Enrolment_Forms_Pack.pdf](Fenote_Raey_Enrolment_Forms_Pack.pdf) |
| Excel (forms + registers) | Fill in Excel (full or partial), then **Import Excel** in MayaBela | [Fenote_Raey_Enrolment_Forms.xlsx](Fenote_Raey_Enrolment_Forms.xlsx) |
| Teacher registration Excel | Send to the school: identity + homeroom class + subject teaching | [Fnote_Raey_Teacher_Registration.xlsx](Fnote_Raey_Teacher_Registration.xlsx) |

MayaBela reads this workbook on **Students**, **Classroom Teachers**, **Administration Staff**, and **Go-live → Import**. Empty rows are skipped. Missing optional fields stay blank. Gold office ID columns are ignored — the software issues `STU-####` / `TCH-####` / role-prefix IDs after save. Students need a full name and date of birth; teachers and staff need name, a real email, and a login phone.

The **teacher registration** workbook is the one to email Fnote Raey Academy when they must list every classroom teacher from scratch, then assign each person as a homeroom teacher and/or a subject teacher:

- `Teachers` — full name, email, phone (the login). Optional school-file columns (gender, HR ID, qualification).
- `Homeroom by class` — one homeroom teacher per class (grade + section). Phone must match `Teachers`.
- `Subject teaching` — one row per teacher + class, with subjects from the catalogue.

MayaBela reads that file on **Classroom Teachers** or **Go-live → Import**. Gold office ID columns are ignored.

Regenerate after field changes:

```bash
python3 tools/generate_fenote_enrolment_forms.py
python3 tools/generate_fenote_enrolment_excel.py
python3 tools/generate_fnote_teacher_excel.py
```

Do **not** write Student ID / Teacher ID / Staff ID before saving in MayaBela. The software issues `STU-####`, `TCH-####`, or a role prefix such as `QA-####` / `HR-####` / `REG-####`.
