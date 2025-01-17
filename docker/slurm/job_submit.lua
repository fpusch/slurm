--[[
Example lua script demonstrating the Slurm job_submit/lua interface.
This is only an example, not meant for use in its current form.
For use, this script should be copied into a file name "job_submit.lua"
in the same directory as the Slurm configuration file, slurm.conf.
--]]

-- placing this flag inside the job submission script will stop the plugin from defaulting the pfl layout
DISABLE_FLAG = "#JS_AUTO_PFL --disable=1"

-- maximum bandwidth between a single Object Storage Server and its Object Storage Targets
-- this is limited by the storage interconnect (SATA / SAS) and storage technology (HDD / SSD / NVME)
MAX_OSS_OST_BANDWIDTH_MBS = 250
-- maximum bandwidth between a single Compute Node and a single Object Storage Server
-- this is limited by the compute storage interconnect (ethernet / infiniband)
MAX_COMPUTE_OSS_BANDWIDTH_MBS = 1000

-- table of job step executable names mapped to their storage mode
-- 11 = SINGLE_PROCESS_SINGLE_FILE (the job is not parallelized and writes to a single file)
-- 21 = MULTI_PROCESS_SINGLE_FILE (the job is parallelized and writes to a single file)
-- 22 = MULTI_PROCESS_MULTI_FILE (the job is parallelized and writes to multiple files in a file-per-process model)
EXECUTABLE_STORAGE_MODE = {
    pwd = 11,
    hostname = 21,
    date = 22,
    ["ior_sps.slurm"] = 11,
    ["ior_mps.slurm"] = 21,
    ["ior_mpm.slurm"] = 22
}

function slurm_job_submit(job_desc, part_list, submit_uid)
    slurm.log_user("slurm_job_submit: job from uid %u", submit_uid)                                                                                                slurm.log_user("slurm_job_submit: job_desc.name %s", job_desc.name)
    slurm.log_user("slurm_job_submit: job_desc.name %s", job_desc.name)
    slurm.log_user("slurm_job_submit: job_desc.script %s", job_desc.script)
    slurm.log_user("slurm_job_submit: job_desc.work_dir %s", job_desc.work_dir)

    -- check override flag
    if string.find(job_desc.script, DISABLE_FLAG, 1, true) then
        slurm.log_user("slurm_job_submit: disable flag set, backing off")
        return slurm.SUCCESS
    end

    local storage_mode = EXECUTABLE_STORAGE_MODE[job_desc.name]
    if storage_mode == nil then
        slurm.log_user("slurm_job_submit: unknown job executable defaulting to a MULTI_PROCESS_MULTI_FILE config")
        storage_mode = 22
    end
    slurm.log_user("slurm_job_submit: storage_mode %s", storage_mode)

    local pfl_dir = job_desc.work_dir
    local pfl_extents = ""
    if storage_mode == 11 then
        pfl_extents = "-E -1 -c 1"
    elseif storage_mode == 21 then
        pfl_extents = "-E 16M -c 1 -E -1 -c 4"
    elseif storage_mode == 22 then
        pfl_extents = "-E 16M -c 1 -E 128M -c 4 -E -1 -c 16"
    end
    local pfl_cmd = "lfs setstripe " .. pfl_extents .. " " .. pfl_dir
    slurm.log_user("slurm_job_submit: pfl_cmd %s", pfl_cmd)

    -- actual command
    local command = pfl_cmd
    slurm.log_user("slurm_job_submit: os_cmd %s", command)

    -- execute
    local result = os.execute(command)
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

