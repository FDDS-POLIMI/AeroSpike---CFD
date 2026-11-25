// ============================================================
// SPIKED BLUNT BODY -- PARAMETRIC 2D AXISYMMETRIC MERIDIAN
// Dimensioni basate su Senthilkumar et al. (D = 20 mm, L = 2.0D)
// 0 = blunt | 1 = sharp conical (15 deg) | 2 = hemisphere aerodisk 
// ============================================================

DefineConstant[
  geometryConfig = {2, Choices{0="0: Blunt Body", 1="1: Conical Spike", 2="2: Hemisphere Aerodisk"}, Name "Geometry/Model type (0-2)"},
  meshFactor    = {1.0, Min 0.2, Max 5.0, Step 0.1, Name "Mesh/Resolution factor"}
];

// meshFactor scales the global mesh density.

// ---------------------------
// Geometry Parameters (Senthilkumar et al.)
// ---------------------------

D = 0.020;                            // Main bluff body diameter: 20 mm
R = D/2;                              // Hemisphere radius (main body): 10 mm
L = 2.0*R;                            // Spike length: 2.0 * D = 20 mm
shaftD = 0.1*D;                      // Spike shaft diameter: 0.1 * D = 2 mm
shaftR = shaftD/2;                    // Spike shaft radius: 0.1 * R = 1 mm
tipLength = shaftD;                   // x-dimension of the tip


// Parametri Configuration 1 (Conical Spike - 15 degree angle)
coneHalfAngle = 7.5 * Pi / 180.0;     // 15 deg total cone angle (usa 15*Pi/180 se inteso come semi-angolo)
tipLength = shaftR / Tan(coneHalfAngle);

// Parametri Configuration 2 (Hemisphere Aerodisk)
hemiR = 0.25*R;                       // Hemisphere aerodisk radius: 0.1 * D = 2 mm (diametro 4 mm)

// BoundaryLayer field thickness
blThickness = 5e-5;

// Tip-strip parameters matched to the green BoundaryLayer field

tipLen = Sqrt(tipLength*tipLength + shaftR*shaftR);  // total lenght of the tip
tipNormalX = -shaftR/tipLen;  // component of the normal versor in x-dir
tipNormalY = tipLength/tipLen;  // component of the normal versor in y-dir
nBLtip = 11; // number of intervals on the BL in the transfinite lines
rBLtip = 1.15; // transfinite BL growth rate
tBLtip = blThickness; // total thickness of the transfinite lines region


// ---------------------------
// Flow Domain Dimensions
// ---------------------------

xmin = -10*D;                         // Upstream boundary
xmax =  14*D;                         // Downstream boundary (ridotto a 14D come da Fig. 2 del paper)
ymax =  10*D;                         // Farfield radius (10D come da Fig. 2 del paper)

// Intersezione geometrica tra lo stelo e la testa emisferica del corpo principale
xAttach = R - Sqrt(R*R - shaftR*shaftR);
xTip = -L;
xTipOuter = xTip - tBLtip*tipLen/shaftR;

// Basic parameter validity checks
If (shaftR >= R)
  Error("shaft diameter must be smaller than main body diameter");
EndIf
If (tipLength >= L + xAttach)
  Error("sharp spike tip is too long for the chosen L");
EndIf
If (hemiR <= shaftR || hemiR >= R)
  Error("hemisphere aerodisk radius must exceed shaft radius and be below body radius");
EndIf
If (xTip <= xmin)
  Error("spike tip lies outside upstream domain");
EndIf

// ---------------------------
// Mesh Parameters - Coarse mesh for adaptation
// ---------------------------

// Mesh resolution
h_wall = meshFactor*D/50;       // 0.40 mm
h_tip  = meshFactor*D/133.3333; // 0.15 mm
h_far  = meshFactor*D/2.5;      // 8.00 mm

lc = h_far;

// Distance controlling progressive mesh growth
wallDistMin = 0.05*D;  // 1 mm
wallDistMax = 3.00*D;  // 60 mm

tipDistMin  = 0.10*D;  // 2 mm
tipDistMax  = 1.00*D;  // 20 mm

// ---------------------------
// Domain corner points 
// ---------------------------

Point(1) = {xmin, 0,    0, lc};       // Upstream axis
Point(2) = {xmax, R,    0, h_wall};   // Downstream body shoulder
Point(3) = {xmax, ymax, 0, lc};       // Downstream farfield
Point(4) = {xmin, ymax, 0, lc};       // Upstream farfield

// ---------------------------
// External curves, common to all configurations
// ---------------------------

Line(90) = {2, 3};                    // Downstream radial boundary (outlet)
Line(91) = {3, 4};                    // Upper farfield
Line(92) = {4, 1};                    // Upstream radial boundary (inlet)

// ---------------------------
// Shared hemisphere construction (Main Body)
// ---------------------------

Point(10) = {R, 0, 0, lc};            // Arc centre of main body nose
Point(11) = {R, R, 0, lc};            // Main body shoulder

// ---------------------------
// Dynamic lists
// ---------------------------

wallCurves[] = {};   // dynamic list to define all the curves identifying the whole aerospike + bluff body
tipCurves[] = {};    // dynamic list to define all the curves identifying the tip of the aerospike

If (geometryConfig == 0)
  // Blunt hemispherical body, no spike.
  Point(12) = {0, 0, 0, lc};
  Line(1) = {1, 12};
  Circle(2) = {12, 10, 11};
  Line(3) = {11, 2};
  wallCurves[] = {2, 3};
  Curve Loop(1) = {1, 2, 3, 90, 91, 92};

ElseIf (geometryConfig == 1)
  // Sharp spike: transfinite quad strip on the inclined cone,
  // with the structured strip directly adjoining the unstructured fluid domain.
  Point(20) = {xTip, 0, 0, h_wall};
  Point(21) = {xTip + tipLength, shaftR, 0, h_wall};
  Point(22) = {xAttach, shaftR, 0, h_wall};

  // Outer points for the tip strip.
  Point(120) = {xTipOuter, 0, 0, h_wall};
  Point(125) = {
    xTip + tipLength + tBLtip*tipNormalX,
    shaftR + tBLtip*tipNormalY,
    0, h_wall
  };

  // Physical wall geometry.
  Line(1) = {1, 120};
  Line(2) = {20, 21};
  Line(3) = {21, 22};
  Circle(4) = {22, 10, 11};
  Line(5) = {11, 2};
  wallCurves[] = {2, 3, 4, 5};
  tipCurves[] = {2, 3};

  // Tip wedge and shared interface with the remaining fluid domain
  Line(7) = {120, 20};
  Line(306) = {120, 125};
  Line(214) = {21, 125};
  

  // Remaining unstructured fluid domain.
  Curve Loop(1) = {1, 306, -214, 3, 4, 5, 90, 91, 92};

  // Structured tip wedge; its edge 214 is shared with Surface 1.
  Curve Loop(106) = {7, 2, 214, -306};

ElseIf (geometryConfig == 2)
  // Rounded spike: hemispherical tip and shaft.
  Point(30) = {xTip, 0, 0, lc};
  Point(31) = {xTip + hemiR, 0, 0, lc};
  Point(32) = {xTip + hemiR, hemiR, 0, lc};
  Point(33) = {xTip + hemiR, shaftR, 0, lc};
  Point(34) = {xAttach, shaftR, 0, lc};

  Line(1) = {1, 30};
  Circle(2) = {30, 31, 32};
  Line(3) = {32, 33};
  Line(4) = {33, 34};
  Circle(5) = {34, 10, 11};
  Line(6) = {11, 2};

  wallCurves[] = {2, 3, 4, 5,6};
  tipCurves[] = {2, 3, 4};
  Curve Loop(1) = {1, 2, 3, 4, 5, 6, 90, 91, 92};

Else
  Error("configuration must be 0, 1 or 2");
EndIf

// ---------------------------
// Fluid surfaces and transfinite tip mesh
// ---------------------------

If (geometryConfig == 1)
  Plane Surface(1) = {1};  // define the regions where the fluid is
  Plane Surface(106) = {106};

  // Counts are numbers of nodes. The tip edge and its outer edge match. It's needed to define the transfinite region
  tipOuterLen = tipLen + tBLtip*tipLength/shaftR;
  nTip = Ceil(tipOuterLen/h_tip) + 1;
  Transfinite Curve {2, 306} = nTip;
  Transfinite Curve {214} = nBLtip + 1 Using Progression rBLtip;
  Transfinite Curve {7} = nBLtip + 1 Using Progression 1/rBLtip;

  Transfinite Surface {106} = {120, 20, 21, 125};
  Recombine Surface {106};
Else
  Plane Surface(1) = {1};
EndIf

// ---------------------------
// Named boundaries for SU2
// ---------------------------

If (geometryConfig == 1)
  Physical Curve("axis") = {1, 7};
  Physical Surface("fluid") = {1, 106};
Else
  Physical Curve("axis") = {1};
  Physical Surface("fluid") = {1};
EndIf

Physical Curve("wall") = {wallCurves[]};
Physical Curve("outlet") = {90};
Physical Curve("farfield") = {91};
Physical Curve("inlet") = {92};

// ---------------------------
// Graded size field around all walls
// ---------------------------

Field[1] = Distance;
Field[1].CurvesList = {wallCurves[]};
Field[1].Sampling = 300;

Field[2] = Threshold;
Field[2].InField = 1;
Field[2].SizeMin = h_wall;
Field[2].SizeMax = h_far;
Field[2].DistMin = 0.10*D;
Field[2].DistMax = 2.00*D;

If (geometryConfig != 0)
  Field[3] = Distance;
  Field[3].CurvesList = {wallCurves[]};
  Field[3].Sampling = 150;

  Field[4] = Threshold;
  Field[4].InField = 3;
  Field[4].SizeMin = h_tip;
  Field[4].SizeMax = h_far;
  Field[4].DistMin = 1.80*shaftD;
  Field[4].DistMax = 20.00*shaftD;

  Field[5] = Min;
  Field[5].FieldsList = {2, 4};
  Background Field = 5;
Else
  Background Field = 2;
EndIf

// -------------------------
// Boundary layer for RANS
// -------------------------

Field[6] = BoundaryLayer;
Field[6].Size = 2e-6;
Field[6].Ratio = 1.15;
Field[6].Thickness = blThickness;
Field[6].Quads = 1;

If (geometryConfig == 1)
  // The inclined tip BL is the transfinite strip; keep the original
  // BoundaryLayer field on the shaft and body.
  Field[6].CurvesList = {3, 4, 5};
  // Keep the automatic BoundaryLayer field on the shaft and body.
  Field[6].PointsList = {2};
Else
  Field[6].CurvesList = {wallCurves[]};
  If (geometryConfig == 0)
    Field[6].PointsList = {2, 12};
  ElseIf (geometryConfig == 2)
    Field[6].PointsList = {2, 30};
  EndIf
EndIf

BoundaryLayer Field = 6;

// ---------------------------
// Mesh controls
// ---------------------------

Mesh.MeshSizeFromPoints = 0;
Mesh.MeshSizeFromCurvature = 0;
Mesh.MeshSizeExtendFromBoundary = 0;

Mesh.MeshSizeMin = 2e-6;
Mesh.MeshSizeMax = h_far;

// Frontal-Delaunay
Mesh.Algorithm = 6;

// Limit abrupt size transitions
Mesh.Smoothing = 10;

// First-order elements
Mesh.ElementOrder = 1;

Mesh.SaveAll = 0;
