import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import '../widgets/common.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../screens/home_bindings.dart';
import '../screens/chat_screen.dart';
import '../meeting_location.dart';
import '../meeting_map.dart';
import '../widgets/policy_timer.dart';
part 'memory_forms.dart';
part 'profile_form.dart';
part 'post_form.dart';
part 'meeting_forms.dart';

class HomeForms extends HomeBindings
    with MemoryForms, ProfileForm, PostForm, MeetingForms {
  HomeForms(super.context, super.model);
}
