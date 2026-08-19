import 'package:flutter/material.dart';



import 'package:mayabela/l10n/app_strings.dart';

import 'package:mayabela/services/driver_registry_service.dart';

import 'package:mayabela/widgets/admin_form_ui.dart';



/// Bus link ID entry with driver list, autocomplete, and validation feedback.

class TransportDriverField extends StatefulWidget {

  const TransportDriverField({

    super.key,

    required this.controller,

    required this.schoolId,

    required this.accent,

    this.onChanged,

  });



  final TextEditingController controller;

  final String? schoolId;

  final Color accent;

  final VoidCallback? onChanged;



  @override

  State<TransportDriverField> createState() => _TransportDriverFieldState();

}



class _TransportDriverFieldState extends State<TransportDriverField> {

  AdminDriverRecord? _driver;

  String? _lookupMessage;

  bool _lookupOk = false;

  late final FocusNode _focusNode;



  AppStrings get s => AppLocale.instance.strings;



  @override

  void initState() {

    super.initState();

    _focusNode = FocusNode();

    widget.controller.addListener(_onControllerChanged);

    _lookupDriver(silent: true);

  }



  @override

  void didUpdateWidget(covariant TransportDriverField oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (oldWidget.schoolId != widget.schoolId) {

      _lookupDriver(silent: true);

    }

  }



  @override

  void dispose() {

    widget.controller.removeListener(_onControllerChanged);

    _focusNode.dispose();

    super.dispose();

  }



  List<AdminDriverRecord> get _drivers {

    return DriverRegistryService.instance

        .driversForSchool(widget.schoolId)

        .where((d) => d.isActive)

        .toList()

      ..sort((a, b) => a.busId.compareTo(b.busId));

  }



  void _onControllerChanged() {

    _lookupDriver(silent: true);

  }



  void _selectDriver(AdminDriverRecord driver) {

    widget.controller.text = driver.busId;

    _applyDriver(driver);

    widget.onChanged?.call();

  }



  void _applyDriver(AdminDriverRecord driver) {

    setState(() {

      _driver = driver;

      _lookupMessage = s.transportBusRegisteredLabel(

        driver.busId,

        driver.busNumber,

        driver.fullName,

        driver.routeName,

      );

      _lookupOk = true;

    });

  }



  void _lookupDriver({bool silent = false}) {

    final id = widget.controller.text.trim().toUpperCase();

    if (id.isEmpty) {

      setState(() {

        _driver = null;

        _lookupMessage = null;

        _lookupOk = false;

      });

      return;

    }



    final driver = DriverRegistryService.instance.resolveTransportReference(id);

    final schoolId = widget.schoolId?.trim().toUpperCase();

    if (driver == null || !driver.isActive) {

      setState(() {

        _driver = null;

        _lookupMessage = s.transportBusNotRegisteredWithId(id);

        _lookupOk = false;

      });

      if (!silent) widget.onChanged?.call();

      return;

    }

    if (schoolId != null &&

        schoolId.isNotEmpty &&

        driver.schoolId.toUpperCase() != schoolId) {

      setState(() {

        _driver = null;

        _lookupMessage = s.transportIdWrongSchool;

        _lookupOk = false;

      });

      if (!silent) widget.onChanged?.call();

      return;

    }



    setState(() {

      _driver = driver;

      _lookupMessage = s.transportBusRegisteredLabel(

        driver.busId,

        driver.busNumber,

        driver.fullName,

        driver.routeName,

      );

      _lookupOk = true;

    });

    if (!silent) widget.onChanged?.call();

  }



  Iterable<AdminDriverRecord> _filterDrivers(String query) {

    final drivers = _drivers;

    final q = query.trim().toLowerCase();

    if (q.isEmpty) return drivers;

    return drivers.where(

      (d) =>

          d.busId.toLowerCase().contains(q) ||

          d.driverId.toLowerCase().contains(q) ||

          d.fullName.toLowerCase().contains(q) ||

          d.busNumber.toLowerCase().contains(q) ||

          d.routeName.toLowerCase().contains(q),

    );

  }

  String _chipLabel(AdminDriverRecord driver) {
    final route = driver.routeName.trim();
    if (route.isEmpty) {
      return '${driver.busId} · ${driver.busNumber}';
    }
    return '${driver.busId} · ${driver.busNumber} · $route';
  }



  @override

  Widget build(BuildContext context) {

    final drivers = _drivers;



    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        if (drivers.isEmpty)

          Container(

            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(

              color: Colors.orange.shade50,

              borderRadius: BorderRadius.circular(12),

              border: Border.all(color: Colors.orange.shade200),

            ),

            child: Row(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Icon(Icons.info_outline, color: Colors.orange.shade800),

                const SizedBox(width: 8),

                Expanded(

                  child: Text(

                    s.transportNoRegisteredDrivers,

                    style: TextStyle(

                      color: Colors.orange.shade900,

                      height: 1.35,

                    ),

                  ),

                ),

              ],

            ),

          )

        else ...[

          Text(

            s.selectRegisteredBus,

            style: TextStyle(

              fontSize: 13,

              fontWeight: FontWeight.w600,

              color: Colors.grey.shade800,

            ),

          ),

          const SizedBox(height: 8),

          Wrap(

            spacing: 8,

            runSpacing: 8,

            children: drivers.map((driver) {

              final selected = _driver?.busId == driver.busId;

              return FilterChip(

                label: Text(_chipLabel(driver)),

                selected: selected,

                onSelected: (_) => _selectDriver(driver),

                selectedColor: widget.accent.withValues(alpha: 0.18),

                checkmarkColor: widget.accent,

              );

            }).toList(),

          ),

          const SizedBox(height: 12),

        ],

        RawAutocomplete<AdminDriverRecord>(

          textEditingController: widget.controller,

          focusNode: _focusNode,

          optionsBuilder: (value) => _filterDrivers(value.text),

          displayStringForOption: (driver) => driver.busId,

          onSelected: _selectDriver,

          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {

            return TextField(

              controller: controller,

              focusNode: focusNode,

              textCapitalization: TextCapitalization.characters,

              onSubmitted: (_) {

                onFieldSubmitted();

                _lookupDriver();

              },

              decoration: adminFieldDecoration(

                label: '${s.busLinkId} (${s.optionalLabel})',

                hint: s.busLinkIdStudentHint,

                icon: Icons.directions_bus_filled_outlined,

                accent: widget.accent,

              ),

            );

          },

          optionsViewBuilder: (context, onSelected, options) {

            return Align(

              alignment: Alignment.topLeft,

              child: Material(

                elevation: 4,

                borderRadius: BorderRadius.circular(12),

                child: ConstrainedBox(

                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),

                  child: ListView.builder(

                    padding: EdgeInsets.zero,

                    shrinkWrap: true,

                    itemCount: options.length,

                    itemBuilder: (context, index) {

                      final driver = options.elementAt(index);

                      return ListTile(

                        dense: true,

                        title: Text(_chipLabel(driver)),

                        subtitle: Text(driver.fullName),

                        onTap: () => onSelected(driver),

                      );

                    },

                  ),

                ),

              ),

            );

          },

        ),

        Align(

          alignment: Alignment.centerLeft,

          child: TextButton.icon(

            onPressed: () => _lookupDriver(),

            icon: const Icon(Icons.search),

            label: Text(s.lookupBus),

          ),

        ),

        if (_lookupMessage != null)

          Container(

            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(

              color: _lookupOk ? Colors.green.shade50 : Colors.red.shade50,

              borderRadius: BorderRadius.circular(12),

              border: Border.all(

                color: _lookupOk ? Colors.green.shade200 : Colors.red.shade200,

              ),

            ),

            child: Row(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Icon(

                  _lookupOk ? Icons.check_circle : Icons.error_outline,

                  color: _lookupOk ? Colors.green : Colors.red,

                ),

                const SizedBox(width: 8),

                Expanded(child: Text(_lookupMessage!)),

              ],

            ),

          ),

        Padding(

          padding: const EdgeInsets.only(top: 6),

          child: Text(

            s.busLinkIdOptionalHint,

            style: TextStyle(

              fontSize: 12,

              color: Colors.grey.shade700,

              height: 1.35,

            ),

          ),

        ),

      ],

    );

  }

}


