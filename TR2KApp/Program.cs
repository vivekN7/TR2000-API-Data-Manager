using TR2KApp.Components;
using TR2KBlazorLibrary.Logic.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// Add HttpClient
builder.Services.AddHttpClient();

// Add API services only (no database)
builder.Services.AddScoped<TR2000ApiService>();
builder.Services.AddScoped<ApiResponseDeserializer>();

// Add Oracle ETL service
builder.Services.AddScoped<OracleETLService>();
builder.Services.AddScoped<OracleETLServiceV2>(); // New simplified service

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
