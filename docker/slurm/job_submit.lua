--[[
Example lua script demonstrating the Slurm job_submit/lua interface.
This is only an example, not meant for use in its current form.
For use, this script should be copied into a file name "job_submit.lua"
in the same directory as the Slurm configuration file, slurm.conf.
--]]

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
    ior_sps = 11,
    ior_mps = 21,
    ior_mpm = 22
}

function slurm_job_submit(job_desc, part_list, submit_uid)
    slurm.log_user("slurm_job_submit: job from uid %u", submit_uid)
    slurm.log_user("slurm_job_submit: job_desc.name %s", job_desc.name)
    -- slurm.log_user("slurm_job_submit: job_desc.submit_line " .. job_desc.submit_line)
    -- slurm.log_user("slurm_job_submit: job_desc.script %s", job_desc.script)
    slurm.log_user("slurm_job_submit: job_desc.work_dir %s", job_desc.work_dir)
    --[[slurm.log_user("slurm_job_submit: job_desc.environment %s", job_desc.environment)
    local numitems = 0
    for k, v in pairs(job_desc.environment) do
            numitems = numitems + 1
            slurm.log_info("slurm_job_submit: job_desc.environment %s : %s", k, v)
    end
    slurm.log_user("slurm_job_submit: job_desc.environment %s", numitems)
    --]]
    local storage_mode = EXECUTABLE_STORAGE_MODE[job_desc.name]
    if storage_mode == nil then
        slurm.log_user("slurm_job_submit: unknown job executable")
        storage_mode = 22
    end
    slurm.log_user("slurm_job_submit: storage_mode %s", storage_mode)
    local pfl_dir = job_desc.work_dir
    local pfl_extents = ""
    if storage_mode == 11 then
        pfl_extents = "-E -1 -c 1"
    elseif storage_mode == 21 then
        pfl_extents = "-E 16M -c 1 -E 128M -c 4 -E -1 -c 16"
    elseif storage_mode == 22 then
        pfl_extents = "-E 16M -c 1 -E -1 -c 4"
    end
    local pfl_cmd = "lfs setstripe " .. pfl_extents .. " " .. pfl_dir
    slurm.log_user("slurm_job_submit: pfl_cmd %s", pfl_cmd)

    -- dummy command for now
    local command = "echo \"" .. pfl_cmd .. "\" > " .. pfl_dir .. "/cmd.txt"
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

