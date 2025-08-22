using TR2KApp.Components;
using TR2KBlazorLibrary.Logic.Services;
using TR2KBlazorLibrary.Legacy.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// Add HttpClient
builder.Services.AddHttpClient();

// Add API services
builder.Services.AddScoped<TR2000ApiService>();
builder.Services.AddScoped<ApiResponseDeserializer>();

// Add new ETL services
builder.Services.AddScoped<SelectionService>();
builder.Services.AddScoped<ETLService>();

// Add Legacy Oracle ETL service (for legacy page only)
builder.Services.AddScoped<LegacyOracleETLService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
}


app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
