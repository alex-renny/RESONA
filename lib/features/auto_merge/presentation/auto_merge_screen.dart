import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/widgets/resona_card.dart';
import '../../../core/widgets/resona_empty_state.dart';
import '../../editor/presentation/timeline/editor_toolbar.dart'
    show kSupportedAudioExtensions;
import '../application/auto_merge_provider.dart';
import '../domain/auto_merge_models.dart';
import '../domain/auto_merge_validator.dart';

// ── Ordinal helper ────────────────────────────────────────────────────────

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

// ── Fade option model ─────────────────────────────────────────────────────

class _FadeOption {
  final String label;
  final Duration? value; // null = custom
  const _FadeOption(this.label, this.value);
}

const List<_FadeOption> _kFadeOptions = [
  _FadeOption('Off', Duration.zero),
  _FadeOption('0.5 s', Duration(milliseconds: 500)),
  _FadeOption('1 s', Duration(seconds: 1)),
  _FadeOption('2 s', Duration(seconds: 2)),
  _FadeOption('3 s', Duration(seconds: 3)),
  _FadeOption('5 s', Duration(seconds: 5)),
  _FadeOption('Custom', null),
];

// ═════════════════════════════════════════════════════════════════════════════
// AutoMergeScreen
// ═════════════════════════════════════════════════════════════════════════════

class AutoMergeScreen extends ConsumerStatefulWidget {
  const AutoMergeScreen({super.key});

  @override
  ConsumerState<AutoMergeScreen> createState() => _AutoMergeScreenState();
}

class _AutoMergeScreenState extends ConsumerState<AutoMergeScreen> {
  bool _isImporting = false;

  // Global transition settings (applied to all items).
  TransitionType _globalTransition = TransitionType.hardCut;
  double _crossfadeSeconds = 1.0;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: kSupportedAudioExtensions,
    );
    if (result == null || !mounted) return;

    setState(() => _isImporting = true);
    final notifier = ref.read(autoMergeProvider.notifier);
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final duration = await probeDuration(path);
      if (!mounted) break;
      notifier.addItem(path, duration);
    }
    if (mounted) setState(() => _isImporting = false);
  }

  Future<void> _buildMerge() async {
    // Use a simple directory picker via FilePicker or fall back to a Downloads
    // path. On desktop we can pick a save directory.
    String? dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose output folder',
    );
    if (dir == null || !mounted) return;
    await ref.read(autoMergeProvider.notifier).buildMerge(dir);
  }

  void _applyGlobalTransition() {
    ref.read(autoMergeProvider.notifier).setTransitionForAll(
          _globalTransition,
          Duration(milliseconds: (_crossfadeSeconds * 1000).round()),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(autoMergeProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Auto Merge'),
              titlePadding: const EdgeInsetsDirectional.only(
                start: ResonaSpacing.lg,
                bottom: ResonaSpacing.md,
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(ResonaSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Subtitle + import button ────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Combine audio clips automatically',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: ResonaSpacing.md),
                    FilledButton.icon(
                      onPressed: state.isProcessing || _isImporting
                          ? null
                          : _pickFiles,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Add Audio Files'),
                    ),
                  ],
                ),
                const SizedBox(height: ResonaSpacing.xl),

                // ── Empty state ─────────────────────────────────────────
                if (state.items.isEmpty) ...[
                  ResonaEmptyState(
                    icon: Icons.merge_type,
                    title: 'No audio files added yet',
                    message:
                        'Tap "Add Audio Files" to build your merge queue.',
                  ),
                  const SizedBox(height: ResonaSpacing.xl),
                ],

                // ── Reorderable clip list ───────────────────────────────
                if (state.items.isNotEmpty) ...[
                  Text('Clips (${state.items.length})',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: ResonaSpacing.sm),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: state.items.length,
                    onReorder: (oldIndex, newIndex) {
                      ref
                          .read(autoMergeProvider.notifier)
                          .reorderItems(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return _AutoMergeItemCard(
                        key: ValueKey(item.id),
                        item: item,
                        index: index,
                        isProcessing: state.isProcessing,
                      );
                    },
                  ),
                  const SizedBox(height: ResonaSpacing.xl),
                ],

                // ── Transition settings ─────────────────────────────────
                if (state.items.isNotEmpty) ...[
                  Text('Transition Settings',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: ResonaSpacing.sm),
                  ResonaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Between clips',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            )),
                        const SizedBox(height: ResonaSpacing.md),
                        SegmentedButton<TransitionType>(
                          segments: const [
                            ButtonSegment(
                              value: TransitionType.hardCut,
                              label: Text('Hard Cut'),
                              icon: Icon(Icons.cut),
                            ),
                            ButtonSegment(
                              value: TransitionType.crossfade,
                              label: Text('Crossfade'),
                              icon: Icon(Icons.swap_horiz),
                            ),
                            ButtonSegment(
                              value: TransitionType.fadeThroughSilence,
                              label: Text('Fade Through Silence'),
                              icon: Icon(Icons.waves),
                            ),
                          ],
                          selected: {_globalTransition},
                          onSelectionChanged: state.isProcessing
                              ? null
                              : (s) {
                                  setState(
                                      () => _globalTransition = s.first);
                                  _applyGlobalTransition();
                                },
                        ),
                        if (_globalTransition ==
                            TransitionType.crossfade) ...[
                          const SizedBox(height: ResonaSpacing.md),
                          Row(
                            children: [
                              Text(
                                'Crossfade: '
                                '${_crossfadeSeconds.toStringAsFixed(1)} s',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Expanded(
                                child: Slider(
                                  value: _crossfadeSeconds,
                                  min: 0.5,
                                  max: 5.0,
                                  divisions: 18,
                                  label:
                                      '${_crossfadeSeconds.toStringAsFixed(1)} s',
                                  onChanged: state.isProcessing
                                      ? null
                                      : (v) {
                                          setState(
                                              () => _crossfadeSeconds = v);
                                          _applyGlobalTransition();
                                        },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: ResonaSpacing.xl),
                ],

                // ── Error message ───────────────────────────────────────
                if (state.errorMessage != null) ...[
                  _ErrorCard(message: state.errorMessage!),
                  const SizedBox(height: ResonaSpacing.lg),
                ],

                // ── Build button ────────────────────────────────────────
                if (state.items.isNotEmpty && !state.isProcessing) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _buildMerge,
                      icon: const Icon(Icons.merge_type),
                      label: const Text('Build Merge'),
                    ),
                  ),
                  const SizedBox(height: ResonaSpacing.xl),
                ],

                // ── Progress ────────────────────────────────────────────
                if (state.isProcessing) ...[
                  _BuildProgressCard(
                    progress: state.progress,
                    step: state.processingStep,
                  ),
                  const SizedBox(height: ResonaSpacing.xl),
                ],

                // ── Success card ────────────────────────────────────────
                if (state.outputPath != null) ...[
                  _SuccessCard(
                    outputPath: state.outputPath!,
                    onNewMerge: () =>
                        ref.read(autoMergeProvider.notifier).clearAll(),
                  ),
                  const SizedBox(height: ResonaSpacing.xl),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _AutoMergeItemCard
// ═════════════════════════════════════════════════════════════════════════════

class _AutoMergeItemCard extends ConsumerStatefulWidget {
  final AutoMergeItem item;
  final int index;
  final bool isProcessing;

  const _AutoMergeItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.isProcessing,
  });

  @override
  ConsumerState<_AutoMergeItemCard> createState() =>
      _AutoMergeItemCardState();
}

class _AutoMergeItemCardState extends ConsumerState<_AutoMergeItemCard> {
  bool _expanded = false;

  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  String? _startError;
  String? _endError;

  Duration _fadeIn = Duration.zero;
  Duration _fadeOut = Duration.zero;

  bool _customFadeIn = false;
  bool _customFadeOut = false;
  late final TextEditingController _customFadeInCtrl;
  late final TextEditingController _customFadeOutCtrl;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _startCtrl = TextEditingController(
      text: item.startTime == Duration.zero
          ? ''
          : AutoMergeValidator.formatTime(item.startTime),
    );
    _endCtrl = TextEditingController(
      text: item.endTime == Duration.zero
          ? ''
          : AutoMergeValidator.formatTime(item.endTime),
    );
    _fadeIn = item.fadeIn;
    _fadeOut = item.fadeOut;
    _customFadeInCtrl = TextEditingController(
      text: AutoMergeValidator.formatTime(item.fadeIn),
    );
    _customFadeOutCtrl = TextEditingController(
      text: AutoMergeValidator.formatTime(item.fadeOut),
    );
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    _customFadeInCtrl.dispose();
    _customFadeOutCtrl.dispose();
    super.dispose();
  }

  void _commitStart(String value) {
    if (value.trim().isEmpty) {
      _applyUpdate(widget.item.copyWith(startTime: Duration.zero));
      setState(() => _startError = null);
      return;
    }
    final parsed = AutoMergeValidator.parseTime(value.trim());
    if (parsed == null) {
      setState(() => _startError = 'Invalid time (use MM:SS or HH:MM:SS)');
      return;
    }
    setState(() => _startError = null);
    _applyUpdate(widget.item.copyWith(startTime: parsed));
  }

  void _commitEnd(String value) {
    if (value.trim().isEmpty) {
      _applyUpdate(widget.item.copyWith(endTime: Duration.zero));
      setState(() => _endError = null);
      return;
    }
    final parsed = AutoMergeValidator.parseTime(value.trim());
    if (parsed == null) {
      setState(() => _endError = 'Invalid time (use MM:SS or HH:MM:SS)');
      return;
    }
    setState(() => _endError = null);
    _applyUpdate(widget.item.copyWith(endTime: parsed));
  }

  void _applyUpdate(AutoMergeItem updated) {
    ref.read(autoMergeProvider.notifier).updateItem(widget.item.id, updated);
  }

  void _onFadeInSelected(Duration? value) {
    if (value == null) {
      setState(() => _customFadeIn = true);
      return;
    }
    setState(() {
      _customFadeIn = false;
      _fadeIn = value;
    });
    _applyUpdate(widget.item.copyWith(fadeIn: value));
  }

  void _onFadeOutSelected(Duration? value) {
    if (value == null) {
      setState(() => _customFadeOut = true);
      return;
    }
    setState(() {
      _customFadeOut = false;
      _fadeOut = value;
    });
    _applyUpdate(widget.item.copyWith(fadeOut: value));
  }

  void _commitCustomFadeIn(String value) {
    final parsed = AutoMergeValidator.parseTime(value.trim());
    if (parsed == null) return;
    setState(() => _fadeIn = parsed);
    _applyUpdate(widget.item.copyWith(fadeIn: parsed));
  }

  void _commitCustomFadeOut(String value) {
    final parsed = AutoMergeValidator.parseTime(value.trim());
    if (parsed == null) return;
    setState(() => _fadeOut = parsed);
    _applyUpdate(widget.item.copyWith(fadeOut: parsed));
  }

  Duration? _selectedFadeOption(Duration current) {
    for (final opt in _kFadeOptions) {
      if (opt.value == current) return opt.value;
    }
    return null; // custom
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final validation = AutoMergeValidator.validateItem(item);

    final durationText = item.sourceDuration != null
        ? AutoMergeValidator.formatTime(item.sourceDuration!)
        : '…';

    return Padding(
      padding: const EdgeInsets.only(bottom: ResonaSpacing.sm),
      child: ResonaCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Summary row ─────────────────────────────────────────────
            InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
                bottom: Radius.circular(12),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ResonaSpacing.md,
                  vertical: ResonaSpacing.sm,
                ),
                child: Row(
                  children: [
                    // Drag handle
                    ReorderableDragStartListener(
                      index: widget.index,
                      child: Padding(
                        padding: const EdgeInsets.all(ResonaSpacing.sm),
                        child: Icon(
                          Icons.drag_handle,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(width: ResonaSpacing.xs),

                    // Position badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ResonaSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _ordinal(item.position),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: ResonaSpacing.sm),

                    // File name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            durationText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Validation badge
                    if (!validation.isValid)
                      Padding(
                        padding: const EdgeInsets.only(right: ResonaSpacing.xs),
                        child: Tooltip(
                          message: validation.errors.join('\n'),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),

                    // Expand chevron
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded detail panel ───────────────────────────────────
            if (_expanded) ...[
              Divider(height: 1, color: theme.dividerColor),
              Padding(
                padding: const EdgeInsets.all(ResonaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // In/out point row
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            label: 'Start time',
                            hint: '00:00',
                            controller: _startCtrl,
                            error: _startError,
                            enabled: !widget.isProcessing,
                            onSubmitted: _commitStart,
                          ),
                        ),
                        const SizedBox(width: ResonaSpacing.md),
                        Expanded(
                          child: _TimeField(
                            label: 'End time',
                            hint: 'Source end',
                            controller: _endCtrl,
                            error: _endError,
                            enabled: !widget.isProcessing,
                            onSubmitted: _commitEnd,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ResonaSpacing.md),

                    // Fade row
                    Row(
                      children: [
                        Expanded(
                          child: _FadeDropdown(
                            label: 'Fade in',
                            selected: _selectedFadeOption(_fadeIn),
                            enabled: !widget.isProcessing,
                            onChanged: _onFadeInSelected,
                          ),
                        ),
                        const SizedBox(width: ResonaSpacing.md),
                        Expanded(
                          child: _FadeDropdown(
                            label: 'Fade out',
                            selected: _selectedFadeOption(_fadeOut),
                            enabled: !widget.isProcessing,
                            onChanged: _onFadeOutSelected,
                          ),
                        ),
                      ],
                    ),

                    // Custom fade-in input
                    if (_customFadeIn) ...[
                      const SizedBox(height: ResonaSpacing.sm),
                      _TimeField(
                        label: 'Custom fade-in duration',
                        hint: '00:05',
                        controller: _customFadeInCtrl,
                        enabled: !widget.isProcessing,
                        onSubmitted: _commitCustomFadeIn,
                      ),
                    ],

                    // Custom fade-out input
                    if (_customFadeOut) ...[
                      const SizedBox(height: ResonaSpacing.sm),
                      _TimeField(
                        label: 'Custom fade-out duration',
                        hint: '00:05',
                        controller: _customFadeOutCtrl,
                        enabled: !widget.isProcessing,
                        onSubmitted: _commitCustomFadeOut,
                      ),
                    ],

                    // Per-item validation errors
                    if (!validation.isValid) ...[
                      const SizedBox(height: ResonaSpacing.sm),
                      ...validation.errors.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(
                              top: ResonaSpacing.xs),
                          child: Text(
                            e,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: ResonaSpacing.md),

                    // Delete button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: widget.isProcessing
                            ? null
                            : () => ref
                                .read(autoMergeProvider.notifier)
                                .removeItem(item.id),
                        icon: Icon(Icons.delete_outline,
                            color: widget.isProcessing
                                ? null
                                : theme.colorScheme.error),
                        label: Text(
                          'Remove',
                          style: TextStyle(
                            color: widget.isProcessing
                                ? null
                                : theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Small reusable sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

class _TimeField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? error;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  const _TimeField({
    required this.label,
    required this.hint,
    required this.controller,
    this.error,
    required this.enabled,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d:]')),
        LengthLimitingTextInputFormatter(8),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: onSubmitted,
      onEditingComplete: () => onSubmitted(controller.text),
    );
  }
}

class _FadeDropdown extends StatelessWidget {
  final String label;
  final Duration? selected; // null = custom
  final bool enabled;
  final ValueChanged<Duration?> onChanged;

  const _FadeDropdown({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Duration?>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: _kFadeOptions.map((opt) {
        return DropdownMenuItem<Duration?>(
          value: opt.value,
          child: Text(opt.label),
        );
      }).toList(),
      onChanged: enabled ? (v) => onChanged(v) : null,
    );
  }
}

class _BuildProgressCard extends StatelessWidget {
  final double progress;
  final String? step;

  const _BuildProgressCard({required this.progress, this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ResonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: ResonaSpacing.md),
              Expanded(
                child: Text(
                  step ?? 'Processing…',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: ResonaSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final String outputPath;
  final VoidCallback onNewMerge;

  const _SuccessCard({
    required this.outputPath,
    required this.onNewMerge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = outputPath.split(RegExp(r'[\\/]')).last;

    return ResonaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: theme.colorScheme.tertiary),
              const SizedBox(width: ResonaSpacing.sm),
              Text(
                'Merge complete!',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: ResonaSpacing.md),
          Text(
            fileName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            outputPath,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: ResonaSpacing.lg),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  // Open the parent directory in the system file manager.
                  final dir = File(outputPath).parent.path;
                  // ignore: deprecated_member_use
                  Process.run('explorer', [dir], runInShell: true);
                },
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Open Folder'),
              ),
              const SizedBox(width: ResonaSpacing.md),
              FilledButton.icon(
                onPressed: onNewMerge,
                icon: const Icon(Icons.add),
                label: const Text('New Merge'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ResonaCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: ResonaSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
