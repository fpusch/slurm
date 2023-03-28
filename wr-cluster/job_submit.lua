--[[
Lua Job Submission Script adjusting the PFL configuration
--]]

-- placing this flag inside the job submission script will stop the plugin from defaulting the pfl layout
DISABLE_FLAG = "#JS_AUTO_PFL --disable=1"

-- total nodes in the slurm cluster
TOTAL_SLURM_NODES=4
-- total nodes in the lustre cluster
TOTAL_LUSTRE_NODES=5

-- maximum bandwidth between a single Object Storage Server and its Object Storage Targets
-- this is limited by the storage interconnect (SATA / SAS) and storage technology (HDD / SSD / NVME)
MAX_OSS_OST_BANDWIDTH_MBITS = 1000
-- maximum bandwidth between a single Compute Node and the Object Storage Server backbone
-- this is limited by the compute storage interconnect (ethernet / infiniband)
MAX_COMPUTE_OSS_BANDWIDTH_MBITS = 1000
-- total number of Object Storage Servers a single Compute Node can saturate
SINGLE_NODE_MAX_EXTENTS = math.min(
        math.max(1,math.floor(MAX_COMPUTE_OSS_BANDWIDTH_MBITS / MAX_OSS_OST_BANDWIDTH_MBITS)),
        TOTAL_LUSTRE_NODES)

-- table of job step executable names mapped to their storage mode
-- 11 = SINGLE_PROCESS_SINGLE_FILE (the job is not parallelized and writes to a single file)
-- 21 = MULTI_PROCESS_SINGLE_FILE (the job is parallelized and writes to a single file)
-- 22 = MULTI_PROCESS_MULTI_FILE (the job is parallelized and writes to multiple files in a file-per-process model)
EXECUTABLE_STORAGE_MODE = {
    ["ior_sps.slurm"] = 11,
    ["ior_mps.slurm"] = 21,
    ["ior_mpm.slurm"] = 22
}

function slurm_job_submit(job_desc, part_list, submit_uid)
    slurm.log_user("slurm_job_submit: job from uid %u", submit_uid)
    slurm.log_user("slurm_job_submit: job_desc.name %s", job_desc.name)
    slurm.log_user("slurm_job_submit: job_desc.script %s", job_desc.script)
    slurm.log_user("slurm_job_submit: job_desc.work_dir %s", job_desc.work_dir)

    -- check disable flag
    if string.find(job_desc.script, DISABLE_FLAG, 1, true) then
        slurm.log_user("slurm_job_submit: disable flag set, backing off")
        return slurm.SUCCESS
    end

    -- check cluster utilization
    local nodehandle = io.popen("squeue -t running -O NumNodes | awk '{s+=$1} END {print s}'")
    local allocatednodes = nodehandle:read("*number")
    nodehandle:close()
    slurm.log_user("slurm_job_submit: nodes in use " .. tostring(allocatednodes))
    local availablenodes = TOTAL_SLURM_NODES - allocatednodes

    -- check job storage mode
    local storage_mode = EXECUTABLE_STORAGE_MODE[job_desc.name]
    if storage_mode == nil then
        slurm.log_user("slurm_job_submit: unknown job executable defaulting to a MULTI_PROCESS_MULTI_FILE config")
        storage_mode = 22
    end
    slurm.log_user("slurm_job_submit: storage_mode %s", storage_mode)

    -- check job node requests
    local slurm_requested_nodes = math.ceil(job_desc.num_tasks / job_desc.ntasks_per_node)
    slurm.log_user("slurm_job_submit: slurm_requested_nodes " .. tostring(slurm_requested_nodes))

    local pfl_dir = job_desc.work_dir
    local pfl_extents = ""
    if storage_mode == 21 then
        local extents = math.min(slurm_requested_nodes * SINGLE_NODE_MAX_EXTENTS, TOTAL_LUSTRE_NODES)
        if allocatednodes == 0 then
            slurm.log_user("slurm_job_submit: no running jobs detected, mode=eager")
            pfl_extents = "-E 16M -c 1 -E -1 -c " .. tostring(extents)
        elseif availablenodes > 0 then
            slurm.log_user("slurm_job_submit: running jobs detected, mode=limited, availablenodes=" .. tostring(availablenodes))
            pfl_extents = "-E 16M -c 1 -E -1 -c " .. tostring(extents)
        else
            pfl_extents = "-E 16M -c 1 -E -1 -c " .. tostring(extents)
        end
    else
        max_extents = SINGLE_NODE_MAX_EXTENTS
        pfl_extents = "-E -1 -c " .. tostring(max_extents)
    end
    local pfl_cmd = "lfs setstripe " .. pfl_extents .. " " .. pfl_dir
    slurm.log_user("slurm_job_submit: pfl_cmd %s", pfl_cmd)

    -- execute
    local result = os.execute(pfl_cmd)
    slurm.log_user("slurm_job_submit: " .. tostring(result))

    if result then
        slurm.log_user("slurm_job_submit: successfully set PFL configuration for mode " .. storage_mode)
    else
        slurm.log_user("slurm_job_submit: failed to set PFL configuration")
    end

    return slurm.SUCCESS
end

function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)
    return slurm.SUCCESS
end

slurm.log_info("job submit plugin initialized")
return slurm.SUCCESS

