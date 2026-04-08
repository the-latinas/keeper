using api.Data;
using api.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace api.Controllers;

[ApiController]
[Route("api/public/impact")]
public class PublicImpactController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IConfiguration _config;

    public PublicImpactController(AppDbContext db, IConfiguration config)
    {
        _db = db;
        _config = config;
    }

    [AllowAnonymous]
    [HttpGet("girls-served")]
    public Task<ActionResult<PublicMetricDto>> GetGirlsServed(CancellationToken ct)
    {
        var display = _config["PublicImpact:GirlsServedDisplay"] ?? "250+";
        return Task.FromResult<ActionResult<PublicMetricDto>>(Ok(new PublicMetricDto(display)));
    }

    [AllowAnonymous]
    [HttpGet("safehouses")]
    public async Task<ActionResult<PublicMetricDto>> GetSafehouses(CancellationToken ct)
    {
        var count = await _db.Safehouses.CountAsync(ct);
        if (count == 0 &&
            int.TryParse(_config["PublicImpact:SafehousesFallbackWhenEmpty"], out var fallback) &&
            fallback >= 0)
        {
            count = fallback;
        }

        return Ok(new PublicMetricDto(count.ToString()));
    }

    [AllowAnonymous]
    [HttpGet("reintegration-rate")]
    public Task<ActionResult<PublicMetricDto>> GetReintegrationRate(CancellationToken ct)
    {
        var display = _config["PublicImpact:ReintegrationRateDisplay"] ?? "87%";
        return Task.FromResult<ActionResult<PublicMetricDto>>(Ok(new PublicMetricDto(display)));
    }
}
