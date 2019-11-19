unit uGBEUtils3D;

interface

uses System.Math.Vectors, System.Types, FMX.Objects3D, Math, FMX.Controls3D, FMX.Graphics, FMX.Types3D, System.UITypes, FMX.Effects,
     System.UIConsts, System.SysUtils, System.RTLConsts, FMX.Types, FMX.Ani;

  function Barycentre(p1, p2, p3 : TPoint3D; p4 : TPointF):single;
  function CalculerHauteur(mesh : TMesh; P: TPoint3D; miseAEchelle : single; moitieCarte, sizeMap : integer) : single;
  function DetectionCollisionObstacle(mesh : TMesh; objet : TControl3D):boolean;
  function SizeOf3D(const unObjet3D: TControl3D): TPoint3D;
  function CreerHeightmap(const nbSubdivisions: integer; mesh: TMesh; sizeX, sizeY, sizeZ : integer; heightmap: TBitmap):single;
  procedure WavesOnMesh(aPlane : TPlane; origine, P, W : TPoint3D; maxMesh : integer; var temps : single);
  procedure interactionIHM(animation : TAnimation);

type
  TWaveRec = record
    P, W, origine : TPoint3D;
    function Wave(aSum, aX, aY, aT : single):Single;
  end;

  TMeshHelper = class(TCustomMesh);

implementation

//------------------------------------------------------------------------------------------
function Barycentre(p1, p2, p3 : TPoint3D; p4 : TPointF):single;
var
  det, l1, l2, l3, d1, d2, d3,  t1,t2 : single;
begin
  d1 := (p2.z - p3.z);  // Petites optimisations pour ne faire les calculs interm�diaires qu'une seule fois � chaque it�ration
  d2 := (p3.x - p2.x);
  d3 := (p1.x - p3.x);
  det := 1 / ((d1 * d3) + (d2 * (p1.z - p3.z))); // Inverse, permet de remplacer les divisions gourmandes par une multiplication (ainsi, on ne fait la division qu'une fois au lieu de deux � chaque it�ration)
  t1 := (p4.x - p3.x);
  t2 := (p4.y - p3.z);
  l1  := (( d1 * t1) + (d2 * t2 )) * det;
  l2  := ((p3.z - p1.z) * (t1 + (d3 * t2 ))) * det;
  l3  := 1 - l1 - l2;
  result := l1 * p1.y + l2 * p2.y + l3 * p3.y;
end;

//------------------------------------------------------------------------------------------
function CalculerHauteur(mesh : TMesh; P: TPoint3D; miseAEchelle : single; moitieCarte, sizeMap : integer) : single;
var
   grilleX, grilleZ, sizeMapPlus1 : integer;
   xCoord, zCoord, hauteurCalculee : single; // coordonn�es X et Z dans le "carr�"
begin
  sizeMapPlus1 := sizeMap + 1;
  // D�termination des indices permettant d'acc�der a sommet en fonction de la position du joueur
  grilleX := Math.Floor(P.X+moitieCarte);
  grilleZ := Math.Floor(P.Z+moitieCarte);

  // Si on est en dehors du mesh, on force (arbitrairement) la hauteur � la hauteur de la mer
  if (grilleX >= SizeMap) or (grilleZ >= SizeMap) or (grilleX < 0) or (grilleZ < 0) then
  begin
    result := 0;
  end
  else
  begin
    xCoord := Frac(P.X); // position X dans la maille courante
    zCoord := Frac(P.Z); // position y dans la maille courante

    // On calcule la hauteur en fonction des 3 sommets du triangle dans lequel se trouve le joueur
    // On d�termine dans quel triangle on est
    if xCoord <= (1 - zCoord) then
    begin
      hauteurCalculee := Barycentre(TPoint3D.Create(0,-mesh.data.VertexBuffer.Vertices[grilleX + (grilleZ * SizeMapPlus1)].Z,0),
                                  TPoint3D.Create(1,-mesh.data.VertexBuffer.Vertices[grilleX +1+ (grilleZ * SizeMapPlus1)].Z,0),
                                  TPoint3D.Create(0,-mesh.data.VertexBuffer.Vertices[grilleX + ((grilleZ +1)* SizeMapPlus1)].Z,1),
                                  TPointF.Create(xCoord, zCoord));
    end
    else
    begin
      hauteurCalculee := Barycentre(TPoint3D.Create(1,-mesh.data.VertexBuffer.Vertices[grilleX +1+ (grilleZ * SizeMapPlus1)].Z,0),
                                  TPoint3D.Create(1,-mesh.data.VertexBuffer.Vertices[grilleX +1+ ((grilleZ +1) * SizeMapPlus1)].Z,1),
                                  TPoint3D.Create(0,-mesh.data.VertexBuffer.Vertices[grilleX + ((grilleZ +1)* SizeMapPlus1)].Z,1),
                                  TPointF.Create(xCoord, zCoord));
    end;

    hauteurCalculee := hauteurCalculee * miseAEchelle + mesh.Depth*0.5;  // Hauteur calcul�e et mise � l'�chelle (size 50 dans CreerIle et prise en compte des demis hauteurs)
    result := hauteurCalculee;
  end;
end;

//------------------------------------------------------------------------------------------
function DetectionCollisionObstacle(mesh : TMesh; objet : TControl3D):boolean;
var
  unObjet3D:TControl3D; // l'objet en cours de rendu
  DistanceEntreObjets,distanceMinimum: TPoint3D;
  i : integer;
  resultat : boolean;
begin
  resultat := false;
  // Test collision avec enfants directs de mSol
  for I := 0 to mesh.ChildrenCount-1 do
  begin
    if mesh.Children[i].Tag = 1 then
    begin
      // On travail sur l'objet qui est en train d'�tre calcul�
      unObjet3D := TControl3D(mesh.Children[i]);
      DistanceEntreObjets := unObjet3D.AbsoluteToLocal3D(TPoint3D(objet.AbsolutePosition)); // Distance entre l'objet 3d et la balle
      distanceMinimum := (SizeOf3D(unObjet3D) + SizeOf3D(objet)) * 0.5; // distanceMinimum : on divise par 2 car le centre de l'objet est la moiti� de la taille de l'�l�ment sur les 3 composantes X, Y, Z

      // Test si la valeur absolue de position est inf�rieure � la distanceMinimum calcul�e sur chacune des composantes
      if ((Abs(DistanceEntreObjets.X) < distanceMinimum.X) and (Abs(DistanceEntreObjets.Y) < distanceMinimum.Y) and
          (Abs(DistanceEntreObjets.Z) < distanceMinimum.Z)) then
      begin
        resultat := true;
        break;
      end;
    end;
  end;

  result := resultat;
end;

// Renvoi les dimensions de l'objet 3D
function SizeOf3D(const unObjet3D: TControl3D): TPoint3D;
begin
  Result :=NullPoint3D;
  if unObjet3D <> nil then
    result := Point3D(unObjet3D.Width, unObjet3D.Height, unObjet3D.Depth);
end;

//------------------------------------------------------------------------------------------
function CreerHeightmap(const nbSubdivisions: integer; mesh: TMesh; sizeX, sizeY, sizeZ : integer; heightmap: TBitmap): single;
var
  Basic : TPlane;             // TPlane qui va servir de base
  SubMap : TBitMap;           // Bitmap qui va servir pour g�n�rer le relief � partir du heightmap
  Front, Back : PPoint3D;
  M: TMeshData;               // informations du Mesh
  G, S, W, X, Y: Integer;
  hauteurMin, zMap : Single;
  C : TAlphaColorRec;         // Couleur lue dans la heightmap et qui sert � d�terminer la hauteur d'un sommet
  bitmapData: TBitmapData;    // n�cessaire pour pouvoir acc�der aux pixels d'un TBitmap
begin
  if nbSubdivisions < 1 then
  begin
    result := 1;
    exit;  // il faut au moins une subdivision
  end;

  G:=nbSubdivisions + 1;
  S:= G * G;  // Nombre total de maille
  hauteurMin := 0;

  try
    Basic := TPlane.Create(nil);    // Cr�ation du TPlane qui va servir de base � la constitution du mesh
    Basic.SubdivisionsHeight := nbSubdivisions; // le TPlane sera carr� et subdivis� pour le maillage (mesh)
    Basic.SubdivisionsWidth := nbSubdivisions;

    M:=TMeshData.create;       // Cr�ation du TMesh
    M.Assign(TMEshHelper(Basic).Data); // les donn�es sont transf�r�es du TPlane au TMesh

    SubMap:=TBitmap.Create(heightmap.Width,heightmap.Height);  // Cr�ation du bitmap
    SubMap.Assign(heightmap);    // On charge la heightmap

    blur(SubMap.canvas, SubMap, 4);

    if (SubMap.Map(TMapAccess.Read, bitmapData)) then  // n�cessaire pour acc�der au pixel du Bitmap afin d'en r�cup�rer la couleur
    begin
      try
        for W := 0 to S-1 do  // Parcours de tous les sommets du maillage
        begin
          Front := M.VertexBuffer.VerticesPtr[W];    // R�cup�ration des coordonn�es du sommet (TPlane subdivis� pour rappel : on a les coordonn�es en X et Y et Z est encore � 0 pour l'instant)
          Back := M.VertexBuffer.VerticesPtr[W+S];   // Pareil pour la face arri�re
          X := W mod G; // absisse du maillage en cours de traitement
          Y:=W div G; // ordonn�e du maillage en cours de traitement

          C:=TAlphaColorRec(CorrectColor(bitmapData.GetPixel(x,y))); // On r�cup�re la couleur du pixel correspondant dans la heightmap
          zMap := C.R;//(C.R  + C.G  + C.B ); // d�termination de la hauteur du sommet en fonction de la couleur

          if -zMap < hauteurMin then hauteurMin := -zmap;
          Front^.Z := zMap; // on affecte la hauteur calcul�e � la face avant
          Back^.Z := zMap;  // pareil pour la face arri�re
        end;

        M.CalcTangentBinormals; // Calcul de vecteurs binormaux et de tangente pour toutes les faces (permet par exemple de mieux r�agir � la lumi�re)
        mesh.SetSize(sizeX, sizeY,sizeZ);  // Pr�paration du TMesh
        mesh.Data.Assign(M);  // On affecte les donn�es du meshdata pr�c�demment calcul�es au composant TMesh
      finally
        SubMap.Unmap(bitmapData);  // On lib�re le bitmap
      end;
    end;

  finally
    FreeAndNil(SubMap);
    FreeAndNil(M);
    FreeAndNil(Basic);
  end;

  if hauteurMin <> 0 then result := sizeZ / (-hauteurMin)
  else result := -sizeZ;
end;

//------------------------------------------------------------------------------------------
procedure WavesOnMesh(aPlane : TPlane; origine, P, W : TPoint3D; maxMesh : integer; var temps : single);
var
  M:TMeshData;
  i,x,y,MaxMerMeshPlus1, lgMoins1 : integer;
  somme: single;  // Permet de cumuler les hauteurs calculer en cas de plusieurs ondes
  front, back : PPoint3D;
  F : array of TWaveRec;  // Tableau d'ondes
begin
  M:=TMeshHelper(aPlane).Data; // affectation du aPlane au TMeshData afin de pouvoir travailler avec ses mailles

  MaxMerMeshPlus1 := MaxMesh + 1;
  System.setLength(F,1);  // Nous n'utiliserons qu'une seule onde mais le code permet d'en g�rer plusieurs...
  F[0].origine := origine;
  F[0].p := P;
  F[0].w := W;
  lgMoins1 := system.Length(F)-1;

  for y := 0 to MaxMesh do  // Parcours toutes les "lignes" du maillage
     for x := 0 to MaxMesh do // Parcours toutes les "colonnes" du maillage
       begin
         front := M.VertexBuffer.VerticesPtr[X + (Y * MaxMerMeshPlus1)];
         back := M.VertexBuffer.VerticesPtr[MaxMerMeshPlus1 * MaxMerMeshPlus1 + X + (Y * MaxMerMeshPlus1)];
         somme := 0; // initialisation de la somme
         for i := 0 to lgMoins1 do somme:=F[i].Wave(somme, x, y,temps); // Calcul de la hauteur du sommet de la maille
         somme := somme * 100;
         Front^.Z := somme;
         Back^.z := somme;
       end;
  M.CalcTangentBinormals;
  temps := temps + 0.005; // Incr�mentation arbitraire du temps
end;

//------------------------------------------------------------------------------------------
function TWaveRec.Wave(aSum, aX, aY, aT: single): Single;
var l : single;
begin
  l := P.Distance(Point3d(aX,aY,0));
  Result:=aSum;
  if w.Y > 0  then Result:=Result +w.x * sin (1/w.y*l-w.z*at);
end;

//------------------------------------------------------------------------------------------
procedure interactionIHM(animation : TAnimation);
begin
  animation.ProcessTick(0,0);      // Permet de ne pas bloquer les animations pendant que l'utilisateur interagit avec l'interface graphique
end;

end.
