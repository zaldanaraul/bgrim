#!/usr/bin/env bash

# Get the directory of the script that's currently running
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source test library
# shellcheck source=./lib/tst.bash
PATH="$SCRIPT_DIR/lib:$PATH" source tst.bash

setup_suite() {
  export __BG_TEST_MODE="true"
  tst.source_lib_from_root "env.bash"
  tst.source_lib_from_root "trap.bash"
  export __BG_ERR_FORMAT='%s\n'
}

test_env.clear_shell_opts_clears_all_shell_and_bash_specific_options_in_the_environment() {
  # Set a few specific options
  set -euo pipefail
  set -o vi
  shopt -s extglob

  tst.create_buffer_files

  # Run function 
  ret_code=0
  bg.env.clear_shell_opts >"$stdout_file" 2>"$stderr_file" || ret_code="$?"

  # Stderr and stdout are empty
  assert_equals "" "$(cat "$stderr_file")" "stderr should be empty"
  assert_equals "" "$(cat "$stdout_file")" "stdout should be empty"

  # Return code is 0
  assert_equals "0" "$ret_code" "function code should return 0 if all options were unset"

  # All shell options are unset
  assert_equals "" "$-" '$- should expand to an empty string but it doesn'\''t'

  # All bash-specific options are unset
  assert_equals "" "$(shopt -s)" 'There should be no set bash-specific options'
}

test_env.clear_vars_with_prefix_unsets_all_vars_with_the_given_prefix() {
  set -euo pipefail
  tst.create_buffer_files

  # declare some variables
  PREFIX_MY_VAR="my value"
  export PREFIX_ENV_VAR="env value"
  local PREFIX_LOCAL_VAR="local value"
  bg.env.clear_vars_with_prefix "PREFIX_" 2>"$stderr_file" >"$stdout_file"
  exit_code="$?"

  local was_prefix_var_empty
  if declare -p 'prefix' &>/dev/null; then
    was_prefix_var_empty="false"
  else
    was_prefix_var_empty="true"
  fi

  assert_equals "true" "$was_prefix_var_empty" 
  assert_equals "0" "$exit_code"
  assert_equals "" "$(< "$stderr_file")"
  assert_equals "" "$(< "$stdout_file")"
  assert_equals "" "${PREFIX_MY_VAR:-}" "PREFIX_MY_VAR should be empty"
  assert_equals "" "${PREFIX_ENV_VAR:-}" "PREFIX_ENV_VAR should be empty"
  assert_equals "" "${PREFIX_LOCAL_VAR:-}" "PREFIX_LOCAL_VAR should be empty"
}

test_env.clear_vars_with_prefix_returns_error_if_prefix_is_not_a_valid_var_name() {
  set -euo pipefail
  tst.create_buffer_files

  # declare some variables
  PREFIX_MY_VAR='my value'
  export PREFIX_ENV_VAR="env value"
  local PREFIX_LOCAL_VAR="local value"
  bg.env.clear_vars_with_prefix '*' 2>"$stderr_file" >"$stdout_file" \
    || exit_code="$?"
  assert_equals "1" "$exit_code"
  assert_equals "" "$(< "$stdout_file")"
  assert_equals "'*' is not a valid variable prefix" "$(< "$stderr_file")"
  assert_equals "my value" "${PREFIX_MY_VAR:-}" "PREFIX_MY_VAR should be empty"
  assert_equals "env value" "${PREFIX_ENV_VAR:-}" "PREFIX_ENV_VAR should be empty"
  assert_equals "local value" "${PREFIX_LOCAL_VAR:-}" "PREFIX_LOCAL_VAR should be empty"

}

test_env.is_shell_opt_set_returns_0_if_the_given_option_is_set() {
  set -euo pipefail
  local test_opt="pipefail"
  local stdout_and_stderr
  set -o "$test_opt" 
  stdout_and_stderr="$( bg.env.is_shell_opt_set "$test_opt" )"
  ret_code="$?"
  assert_equals "0" "$ret_code"
  assert_equals "" "$stdout_and_stderr"
}

test_env.is_shell_opt_set_returns_1_if_the_given_option_is_not_set() {
  local test_opt="pipefail"
  local stdout_and_stderr
  set +o "$test_opt" 
  stdout_and_stderr="$( bg.env.is_shell_opt_set "$test_opt" )"
  ret_code="$?"
  assert_equals "1" "$ret_code"
  assert_equals "" "$stdout_and_stderr"
}

test_env.is_shell_opt_set_returns_2_if_the_given_option_is_not_valid() {
  local test_opt="ipefail"
  local stdout
  local stderr_file
  stderr_file="$(mktemp)"
  tst.rm_on_exit "$stderr_file"
  stdout="$( bg.env.is_shell_opt_set "$test_opt" 2>"$stderr_file" )"
  ret_code="$?"
  assert_equals "2" "$ret_code"
  assert_equals "" "$stdout"
  assert_equals "'ipefail' is not a valid shell option" "$(< "$stderr_file")"
}

test_env.get_parent_routine_name_returns_name_of_parent_of_currently_executing_func_if_within_nested_func() {
  set -euo pipefail
  tst.create_buffer_files

  test_func1() {
    bg.env.get_parent_routine_name
  }

  test_func2() {
    test_func1 
  }


  test_func2 >"$stdout_file" 2>"$stderr_file" 
  ret_code="$?"
  assert_equals "0" "$ret_code" "should return exit code 0"
  assert_equals "test_func2" "$(< "$stdout_file")" "stdout should contain 'test_func2'"
  assert_equals "" "$(< "$stderr_file" )" "stderr should be empty"
}

test_env.get_parent_routine_name_returns_name_of_script_if_executing_at_top_level() {
  set -euo pipefail
  tst.create_buffer_files
  ./test_scripts/get_parent_routine1.bash >"$stdout_file" 2>"$stderr_file" 
  ret_code="$?"
  assert_equals "0" "$ret_code" "should return exit code 0"
  assert_equals "get_parent_routine1.bash" "$(< "$stdout_file")" "stdout should contain 'get_parent_routine.bash'"
  assert_equals "" "$(< "$stderr_file" )" "stderr should be empty"
}

test_get_parent_routine_name_returns_name_of_script_if_currently_executing_func_is_at_top_level() {
  set -euo pipefail
  tst.create_buffer_files
  ./test_scripts/get_parent_routine2.bash >"$stdout_file" 2>"$stderr_file" 
  ret_code="$?"
  assert_equals "0" "$ret_code" "should return exit code 0"
  assert_equals "get_parent_routine2.bash" "$(< "$stdout_file")" "stdout should contain 'get_parent_routine.bash'"
  assert_equals "" "$(< "$stderr_file" )" "stderr should be empty"
}

test_get_parent_script_name_returns_name_of_script_currently_executing_if_called_from_parent_script() {
  set -euo pipefail
  tst.create_buffer_files
  ./test_scripts/get_parent_script1.bash >"$stdout_file" 2>"$stderr_file" 
  ret_code="$?"
  assert_equals "0" "$ret_code" "should return exit code 0"
  assert_equals "get_parent_script1.bash" "$(< "$stdout_file")" "stdout should contain 'get_parent_script1.bash'"
  assert_equals "" "$(< "$stderr_file" )" "stderr should be empty"
}

test_get_parent_script_name_returns_name_of_script_currently_executing_if_called_from_sourced_lib() {
  set -euo pipefail
  tst.create_buffer_files
  ./test_scripts/get_parent_script2.bash >"$stdout_file" 2>"$stderr_file" 
  ret_code="$?"
  assert_equals "0" "$ret_code" "should return exit code 0"
  assert_equals "get_parent_script2.bash" "$(< "$stdout_file")" "stdout should contain 'get_parent_script2.bash'"
  assert_equals "" "$(< "$stderr_file" )" "stderr should be empty"
}

test_env.get_stackframe:returns_same_information_as_caller_builtin_in_output_arr(){
  tst.create_buffer_files
  set -euo pipefail
  local -a stackframe=()
  __bg.env.get_stackframe "0" "stackframe" >"$stdout_file" 2>"$stderr_file"
  ret_code="$?"
  assert_equals "0" "$ret_code"
  assert_equals "" "$(< "$stdout_file")"
  assert_equals "" "$(< "$stderr_file")"
  rm "$stdout_file" "$stderr_file" 
  touch "$stdout_file" "$stderr_file"
  caller 0 >"$stdout_file"
  assert_equals "$(< "$stdout_file")" "${stackframe[0]} ${stackframe[1]} ${stackframe[2]}"
}

test_env.get_stackframe:returns_same_information_as_caller_builtin_in_output_arr_when_requesting_non_zero_frame(){
  tst.create_buffer_files
  set -euo pipefail
  local -a stackframe=()
  __bg.env.get_stackframe "1" "stackframe" >"$stdout_file" 2>"$stderr_file"
  ret_code="$?"
  assert_equals "0" "$ret_code"
  assert_equals "" "$(< "$stdout_file")"
  assert_equals "" "$(< "$stderr_file")"
  rm "$stdout_file" "$stderr_file" 
  touch "$stdout_file" "$stderr_file"
  caller 1 >"$stdout_file"
  assert_equals "$(< "$stdout_file")" "${stackframe[0]} ${stackframe[1]} ${stackframe[2]}"
}

test_env.get_stackframe:returns_same_information_as_caller_builtin_when_called_in_function_from_sourced_file(){
  tst.create_buffer_files
  set -euo pipefail
  . ./test_scripts/test_env.get_stackframe1.bash
  myfunc >"$stdout_file" 2>"$stderr_file"
  ret_code="$?"
  assert_equals "0" "$ret_code"
  assert_equals "$(< "$stdout_file" )" "$(< "$stderr_file")"
}

test_env.get_stackframe:returns_same_information_as_caller_builtin_when_called_in_function_from_sourced_file_in_nested_function(){
  tst.create_buffer_files
  set -euo pipefail
  . ./test_scripts/test_env.get_stackframe2.bash
  myfunc >"$stdout_file" 2>"$stderr_file"
  ret_code="$?"
  assert_equals "0" "$ret_code"
  assert_equals "$(< "$stdout_file" )" "$(< "$stderr_file")"
}

test_env.get_stackframe:returns_fails_when_caller_fails(){
  tst.create_buffer_files
  set -euo pipefail
  local caller_i=0
  while caller "$caller_i" >/dev/null 2>&1; do
    (( ++caller_i ))
  done

  local stackframe=()
  local get_stackframe_i=0
  while __bg.env.get_stackframe "$get_stackframe_i" 'stackframe' 2>"$stderr_file"; do
    (( ++get_stackframe_i ))
  done

  assert_equals "$caller_i" "$get_stackframe_i"
  assert_equals \
    "requested frame '${get_stackframe_i}' but there are only frames 0-$((get_stackframe_i-1)) in the call stack" \
    "$(< "$stderr_file" )"
}

test_env.format_stackframe:prints_formatted_stackframe_from_given_array_name(){
  tst.create_buffer_files
  local -a stackframe=( "72" "myfunc" "myfile" )
  __bg.env.format_stackframe 'stackframe' >"$stdout_file" 2>"$stderr_file"
  ret_code="$?"
  assert_equals "0" "$ret_code" "should return exit code 0"
  assert_equals "" "$(< "$stderr_file")" "stderr should be empty"
  assert_equals "  at myfunc (myfile:72)" "$(< "$stdout_file")"
}

test_env.format_stackframe:returns_error_if_array_has_less_than_3_elements(){
  tst.create_buffer_files
  local -a stackframe=( "72" "myfunc" )
  __bg.env.format_stackframe 'stackframe' >"$stdout_file" 2>"$stderr_file"
  ret_code="$?"
  assert_equals "1" "$ret_code" "should return exit code 0"
  assert_equals                                   \
    "array 'stackframe' has less than 3 elements" \
    "$(< "$stderr_file")"                         \
    "stderr should contain error message"
  assert_equals           \
    ""                    \
    "$(< "$stdout_file")" \
    "stdout should be empty"
}

test_env.format_stackframe:returns_error_if_array_has_more_than_3_elements(){
  tst.create_buffer_files
  local -a stackframe=( "72" "myfunc" "myfile" "extra" )
  __bg.env.format_stackframe 'stackframe' >"$stdout_file" 2>"$stderr_file"
  ret_code="$?"
  assert_equals "1" "$ret_code" "should return exit code 0"
  assert_equals                                   \
    "array 'stackframe' has more than 3 elements" \
    "$(< "$stderr_file")"                         \
    "stderr should contain error message"
  assert_equals           \
    ""                    \
    "$(< "$stdout_file")" \
    "stdout should be empty"
}

test_env.print_stacktrace:calls_get_stacktrace_starting_at_the_given_frame_until_it_fails() {
  set -euo pipefail
  tst.create_buffer_files
  local -i stackframe_count=0
  local -a stackframe=()
  # shellcheck disable=SC2317
  __bg.env.get_stackframe() {
    # shellcheck disable=SC2034
    local -i requested_frame="$1"
    local -a out_arr="$2"

    # empty out arr
    if (( requested_frame >= 3 )); then
      echo "end of stack!" >&2
      return 1
    fi

    eval "$out_arr=( '$stackframe_count' 'func$stackframe_count' 'file$stackframe_count' )"
    (( ++stackframe_count ))
  }

  __bg.env.print_stacktrace "0" >"$stdout_file" 2>"$stderr_file"
  ret_code="$?"
  assert_equals "0" "$ret_code" "should return exit code 0"
  assert_equals         \
    "3"                 \
    "$stackframe_count" \
    "__bg.env.get_stackframe should have been called at least 3 times"
  local expected_stdout
  local -a sf1=( "0" "func0" "file0" )
  local -a sf2=( "1" "func1" "file1" )
  local -a sf3=( "2" "func2" "file2" )
  printf -v expected_stdout                              \
    '%s\n%s\n%s'                                         \
    "$( __bg.env.format_stackframe sf1 )" \
    "$( __bg.env.format_stackframe sf2 )" \
    "$( __bg.env.format_stackframe sf3 )" 
  assert_equals "$expected_stdout" "$(< "$stdout_file" )"
  assert_equals "" "$(< "$stderr_file")" "stderr should be empty"
}

test_env.exit:sets_env_var_and_exits_with_provided_code() {
  set -euo pipefail
  tst.create_buffer_files
  local requested_exit_code
  local first_execution="true"
  exit() {
    if [[ "$first_execution" == "true" ]]; then
      requested_exit_code="$1" 
      first_execution="false"
    fi
  }
  bg.env.exit "23" >"$stdout_file" 2>"$stderr_file"
  assert_equals "" "$(< "$stdout_file" )"
  assert_equals "" "$(< "$stderr_file" )"
  assert 'bg.var.is_set __bg_env_exited_gracefully'
  assert_equals "23" "$requested_exit_code"
}

test_env.exit:sets_env_var_and_exits_with_0_if_no_code_is_provided() {
  #set -euo pipefail
  tst.create_buffer_files
  local requested_exit_code
  local first_execution="true"
  exit() {
    if [[ "$first_execution" == "true" ]]; then
      requested_exit_code="$1" 
      first_execution="false"
    fi
  }
  bg.env.exit >"$stdout_file" 2>"$stderr_file"
  assert_equals "" "$(< "$stdout_file" )"
  assert_equals "" "$(< "$stderr_file" )"
  assert 'bg.var.is_set __bg_env_exited_gracefully'
  assert_equals "0" "$requested_exit_code"
}

test_env.exit:sets_env_var_and_exits_with_1_if_exit_code_is_higher_than_255() {
  set -euo pipefail
  tst.create_buffer_files
  local requested_exit_code
  local first_execution="true"
  exit() {
    if [[ "$first_execution" == "true" ]]; then
      requested_exit_code="$1" 
      first_execution="false"
    fi
  }
  bg.env.exit 300 >"$stdout_file" 2>"$stderr_file"
  assert_equals "" "$(< "$stdout_file" )"
  assert_equals "" "$(< "$stderr_file" )"
  assert 'bg.var.is_set __bg_env_exited_gracefully'
  assert_equals "1" "$requested_exit_code"
}

test_env.__BG_ENV_STACKTRACE_OUT_is_set_to_a_default_after_sourcing_library() {
  set -euo pipefail
  tst.create_buffer_files
  unset __BG_ENV_STACKTRACE_OUT  
  tst.source_lib_from_root "env.bash"
  bg.var.is_set "BG_ENV_STACKTRACE_OUT"
  assert_equals "&2" "$BG_ENV_STACKTRACE_OUT"
}

test_env.handle_non_zero_exit_code_prints_error_message_to_file_specified_in_env_var() {
  set -euo pipefail
  tst.create_buffer_files
  BG_ENV_STACKTRACE_OUT="$stdout_file"
  bg.env.exit() {
    :
  }
  local -i stackframe_requested
  __bg.env.print_stacktrace() {
    stackframe_requested="$1"
    echo "stacktrace"
  }
  :
  __bg.env.handle_non_zero_exit_code >"$stderr_file" 2>&1
  ret_code="$?"
  assert_equals            \
    ""                     \
    "$(< "$stderr_file" )" \
    "stderr and stdout should be empty"
  printf                    \
    -v expected_output      \
    '%s\n%s'                \
    'NON-ZERO EXIT CODE: 0' \
    'stacktrace'
  assert_equals "$expected_output" "$(< "$stdout_file" )"
  assert_equals             \
    "1"                     \
    "$stackframe_requested" \
    "should call print_stackframe with 1 as its arg"
}

test_env.handle_non_zero_exit_code_prints_error_message_to_fd_specified_in_env_var() {
  set -euo pipefail
  tst.create_buffer_files
  local -i stackframe_requested
  __bg.env.print_stacktrace() {
    stackframe_requested="$1"
    echo "stacktrace"
  }
  bg.env.exit() {
    :
  }
  exec 3>"$stdout_file"
  BG_ENV_STACKTRACE_OUT="&3"
  :
  __bg.env.handle_non_zero_exit_code >"$stderr_file" 2>&1
  assert_equals            \
    ""                     \
    "$(< "$stderr_file" )" \
    "stderr and stdout should be empty"
  printf                    \
    -v expected_output      \
    '%s\n%s'                \
    'NON-ZERO EXIT CODE: 0' \
    'stacktrace'
  assert_equals "$expected_output" "$(< "$stdout_file" )"
  assert_equals             \
    "1"                     \
    "$stackframe_requested" \
    "should call print_stackframe with 1 as its arg"
}

test_env.handle_non_zero_exit_code_calls_env.exit_with_previous_exit_code() {
  set -uo pipefail
  tst.create_buffer_files
  local -i stackframe_requested
  __bg.env.print_stacktrace() {
    stackframe_requested="$1"
    echo "stacktrace"
  }
  # mock exit function
  local requested_exit_code
  bg.env.exit() {
    requested_exit_code="$1"
  }
  myfunc() { return 23; }
  myfunc
  __bg.env.handle_non_zero_exit_code >"$stdout_file" 2>"$stderr_file"
  assert_equals "" "$(< "$stdout_file" )" "stdout should be empty"
  printf -v expected_output '%s' 'NON-ZERO EXIT CODE: 23'
  printf                     \
    -v expected_output       \
    '%s\n%s'                 \
    'NON-ZERO EXIT CODE: 23' \
    'stacktrace'
  assert_equals "$expected_output" "$(< "$stderr_file" )"
  assert_equals "23" "$requested_exit_code"
}

test_env.handle_unset_var_exits_with_previous_exit_code_if__bg_env_exited_gracefully_variable_is_set() {
  tst.create_buffer_files
  set -uo pipefail
  myfunc() { return 43; }
  local requested_exit_code
  local first_execution="true"
  exit() {
    if [[ "$first_execution" == "true" ]]; then
      requested_exit_code="$1" 
      first_execution="false"
    fi
  }
  __bg_env_exited_gracefully="0"
  myfunc
  __bg.env.handle_unset_var >"$stdout_file" 2>"$stderr_file"
  assert_equals "43" "$requested_exit_code"  
  assert_equals "" "$(< "$stdout_file" )" "stdout should be empty"
  assert_equals "" "$(< "$stderr_file" )" "stderr should be empty"
}

test_env.handle_unset_var_prints_error_and_stacktrace_to_specified_file_if__bg_env_exited_gracefully_variable_is_not_set() {
  tst.create_buffer_files
  set -uo pipefail
  BG_ENV_STACKTRACE_OUT="$stdout_file"
  local stackframe_requested
  __bg.env.print_stacktrace() {
    stackframe_requested="$1"
    echo "stacktrace"
  }
  :
  myfunc() { return 43; }
  local requested_exit_code
  local first_execution="true"
  exit() {
    if [[ "$first_execution" == "true" ]]; then
      requested_exit_code="$1" 
      first_execution="false"
    fi
  }
  myfunc
  __bg.env.handle_unset_var >"$stdout_file" 2>"$stderr_file"
  assert_equals "1" "$stackframe_requested"
  printf                     \
    -v expected_output       \
    '%s\n%s'                 \
    'UNSET VARIABLE' \
    'stacktrace'
  assert_equals "1" "$requested_exit_code"  
  assert_equals \
    "$expected_output" \
    "$(< "$stdout_file" )" \
    "stdout should be empty"
  assert_equals "" "$(< "$stderr_file" )" "stderr should be empty"
}


test_env.handle_unset_var_prints_error_and_stacktrace_to_specified_fd_if__bg_env_exited_gracefully_variable_is_not_set() {
  tst.create_buffer_files
  set -uo pipefail
  BG_ENV_STACKTRACE_OUT="&3"
  exec 3>"$stdout_file"
  local stackframe_requested
  __bg.env.print_stacktrace() {
    stackframe_requested="$1"
    echo "stacktrace"
  }
  :
  myfunc() { return 43; }
  local requested_exit_code
  local first_execution="true"
  exit() {
    if [[ "$first_execution" == "true" ]]; then
      requested_exit_code="$1" 
      first_execution="false"
    fi
  }
  myfunc
  __bg.env.handle_unset_var >"$stdout_file" 2>"$stderr_file"
  assert_equals "1" "$stackframe_requested"
  printf                     \
    -v expected_output       \
    '%s\n%s'                 \
    'UNSET VARIABLE' \
    'stacktrace'
  assert_equals "1" "$requested_exit_code"  
  assert_equals \
    "$expected_output" \
    "$(< "$stdout_file" )" \
    "stdout should be empty"
  assert_equals "" "$(< "$stderr_file" )" "stderr should be empty"
}

test_env.enable_safe_mode_sets_appropriate_shell_options_and_traps() {
  tst.create_buffer_files
  bg.env.enable_safe_mode >"$stdout_file" 2>"$stderr_file"
  # sets errexit to exit on non-zero exit codes
  assert "bg.env.is_shell_opt_set 'errexit'"
  # sets errtrace so ERR trap is inherited by shell functions
  assert "bg.env.is_shell_opt_set 'errtrace'"
  # sets nounset to fail when trying to read unset variables
  assert "bg.env.is_shell_opt_set 'nounset'"
  # sets pipefail so any failures in a pipeline before
  # the last command cause the whole pipeline command
  # to fail
  assert "bg.env.is_shell_opt_set 'pipefail'"

  assert_equals "" "$(< "$stdout_file")" "stdout should be empty"
  assert_equals "" "$(< "$stderr_file")" "stderr should be empty"

  # Mock error handling functions
  __bg.env.handle_non_zero_exit_code() { :; }
  __bg.env.handle_unset_var() { :; }

  bg.trap.get 'ERR' >"$stdout_file"
  bg.trap.get 'EXIT' >"$stderr_file"

  # Retrieve second exit trap
  local -a err_traps=()
  bg.arr.from_stdin 'err_traps' <"$stderr_file"
  assert_equals                 \
    "__bg.env.handle_non_zero_exit_code" \
    "$(< "$stdout_file")"       \
    "handle_non_zero_exit_code should be set on ERR trap"
  assert_equals           \
    "__bg.env.handle_unset_var"    \
    "${err_traps[1]}" \
    "handle_unset_var should be set on EXIT trap"
}
