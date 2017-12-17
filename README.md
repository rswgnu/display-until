# display-until - Display a window or frame topmost in the frame stack until a condition or timeout occurs.

(RSW would like this code to be added to core Emacs if it is
 acceptable.  Someone else who adds to Emacs regularly would have
 to add the NEWS entry, Elisp Manual entry and commit the code.
 In that case, the utilty macros and function names could be generalized).

This library temporarily displays an existing or new frame topmost in
the frame stack.  Then it restores the prior topmost frame as well
as any prior visibility status of the temporarily displayed frame,
e.g. if it was hidden or iconified.  See the end of the file for
sample usage expressions.

```
This library includes the following:
  Variable:
    display-until-delay - time in seconds to display a temporary frame or
      window
      
  Display Functions:
    display-window-until - given a window and optional buffer, display the
      buffer in the window, make the window's frame topmost for
      `display-until-delay' seconds, then return the window's frame
      to its prior visibility

    display-frame-until - given a frame and optional buffer, display the
      buffer in the frame's selected window, make the frame topmost for
      `display-until-delay' seconds, then return the frame to its prior
      visibility

  Utility Functions:
    display-until-get-frame-by-name - given a name string, return the
      matching frame or nil

  Utility Macros:
    display-until-condition-or-timeout - wait for a boolean condition
      or timeout seconds
    display-until-thread-condition-or-timeout - run a thread until a boolean
      condition or timeout seconds
```
