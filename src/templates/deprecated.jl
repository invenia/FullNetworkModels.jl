# Begin: Deprecated in v6, remove before release of v7

###
### UC
###

@deprecate(
    unit_commitment_no_ramps(
        system::SystemDA, solver=nothing, datetimes=get_datetimes(system);
        relax_integrality=false, slack=nothing,
    ),
    unit_commitment(
        system, solver, datetimes;
        relax_integrality=relax_integrality, slack=slack,
        ramp_rates=false
    )
)
@deprecate(
    unit_commitment_branch_flow_limits(
        system::SystemDA, solver=nothing, datetimes=get_datetimes(system);
        relax_integrality=false, slack=nothing, threshold=_SF_THRESHOLD
    ),
    unit_commitment(
        system, solver, datetimes;
        relax_integrality=relax_integrality, slack=slack, threshold=threshold,
        branch_flows=true
    )
)
@deprecate(
    unit_commitment_no_ramps_branch_flow_limits(
        system::SystemDA, solver=nothing, datetimes=get_datetimes(system);
        relax_integrality=false, slack=nothing, threshold=_SF_THRESHOLD
    ),
    unit_commitment(
        system, solver, datetimes;
        relax_integrality=relax_integrality, slack=slack, threshold=threshold,
        branch_flows=true, ramp_rates=false
    )
)

###
### ED
###

@deprecate(
    economic_dispatch_branch_flow_limits(
        system::SystemRT, solver=nothing, datetimes=get_datetimes(system);
        slack=1e6, threshold=_SF_THRESHOLD
    ),
    economic_dispatch(
        system::SystemRT, solver, datetimes;
        slack=1e6, threshold=threshold, branch_flows=true
    )
)

# End: Deprecated in v6, remove before release of v7
