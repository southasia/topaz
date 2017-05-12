// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modular.services.story/story_provider.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_provider.fidl.dart';
import 'package:apps.modular.services.user/focus.fidl.dart';
import 'package:apps.modular.services.user/user_context.fidl.dart';
import 'package:apps.modular.services.user/user_shell.fidl.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart';

/// Called when [UserShell.initialize] occurs.
typedef void OnReady(
  UserContext userContext,
  FocusProvider focusProvider,
  FocusController focusController,
  VisibleStoriesController visibleStoriesController,
  StoryProvider storyProvider,
  SuggestionProvider suggestionProvider,
);

/// Implements a UserShell for receiving the services a [UserShell] needs to
/// operate.
class UserShellImpl extends UserShell {
  final UserContextProxy _userContextProxy = new UserContextProxy();
  final FocusProviderProxy _focusProviderProxy = new FocusProviderProxy();
  final FocusControllerProxy _focusControllerProxy = new FocusControllerProxy();
  final VisibleStoriesControllerProxy _visibleStoriesControllerProxy =
      new VisibleStoriesControllerProxy();
  final StoryProviderProxy _storyProviderProxy = new StoryProviderProxy();
  final SuggestionProviderProxy _suggestionProviderProxy =
      new SuggestionProviderProxy();

  /// Called when [initialize] occurs.
  final OnReady onReady;

  /// Called when the [UserShell] terminates.
  final VoidCallback onStop;

  /// Constructor.
  UserShellImpl({
    this.onReady,
    this.onStop,
  });

  @override
  void initialize(
    InterfaceHandle<UserContext> userContextHandle,
    InterfaceHandle<UserShellContext> userShellContextHandle,
  ) {
    if (onReady != null) {
      _userContextProxy.ctrl.bind(userContextHandle);
      UserShellContextProxy userShellContextProxy = new UserShellContextProxy();
      userShellContextProxy.ctrl.bind(userShellContextHandle);
      userShellContextProxy
          .getStoryProvider(_storyProviderProxy.ctrl.request());
      userShellContextProxy
          .getSuggestionProvider(_suggestionProviderProxy.ctrl.request());
      userShellContextProxy.getVisibleStoriesController(
        _visibleStoriesControllerProxy.ctrl.request(),
      );
      userShellContextProxy
          .getFocusController(_focusControllerProxy.ctrl.request());
      userShellContextProxy
          .getFocusProvider(_focusProviderProxy.ctrl.request());
      userShellContextProxy.ctrl.close();
      onReady(
        _userContextProxy,
        _focusProviderProxy,
        _focusControllerProxy,
        _visibleStoriesControllerProxy,
        _storyProviderProxy,
        _suggestionProviderProxy,
      );
    }
  }

  @override
  void terminate(void done()) {
    onStop?.call();
    _userContextProxy.ctrl.close();
    _storyProviderProxy.ctrl.close();
    _suggestionProviderProxy.ctrl.close();
    _visibleStoriesControllerProxy.ctrl.close();
    _focusControllerProxy.ctrl.close();
    _focusProviderProxy.ctrl.close();
    done();
  }
}
