#!/usr/bin/env bash
# ============================================================
# sysguard-completion.sh
# Bash completion para SysGuard CLI
# ============================================================

_sysguard_opts() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    # Solo sugerir flags si el usuario ya escribió un guion
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W \
            "--check-firewall --analyze-logs --metrics-use --help" \
            -- "${cur}") )
    fi
}

complete -F _sysguard_opts sysguard
complete -F _sysguard_opts ./sysguard.py

if [[ -n "${BASH_COMPLETION_VERSHOWSION:-}" ]] || \
   declare -F _completion_loader &>/dev/null; then
    : 
else

    _sysguard_sudo_wrapper() {
        local cmd="${COMP_WORDS[1]:-}"
        if [[ "${cmd}" == "sysguard" || "${cmd}" == "./sysguard.py" ]]; then
            _sysguard_opts
        fi
    }
    complete -F _sysguard_sudo_wrapper sudo
fi
